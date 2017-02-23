global with sharing class SB_Sustainers_Batch implements Database.Batchable<SObject>, Database.Stateful {

    global Springboard springboard;
    global List<Contact> contacts;
    global String upgradeAmountField;
    global String upgradeFormId;
    global Datetime tokenExpiration;
    global Integer autologoutSeconds;
    global List<String> excludedGateways;
    
    global SB_Sustainers_Batch() {
        this.springboard = new Springboard();
        Integer tokenLifespan;
        // Set defaults.
        tokenLifespan = 60;
        this.upgradeAmountField = 'Upgrade_Amount__c';
        this.autologoutSeconds = NULL;
        this.excludedGateways = new List<String>();
        // Override defaults where possible.
    	if (this.springboard.settings.Sustainers_HMAC_Token_Lifespan__c != NULL) {
            tokenLifespan = Integer.valueOf(this.springboard.settings.Sustainers_HMAC_Token_Lifespan__c);
    	}
    	if (this.springboard.settings.Sustainers_Upgrade_Amount_Field__c != NULL) {
            this.upgradeAmountField = this.springboard.settings.Sustainers_Upgrade_Amount_Field__c;
    	}
        if (this.springboard.settings.Sustainers_Upgrade_Form_Id__c != NULL) {
            this.upgradeFormId = String.valueOf(this.springboard.settings.Sustainers_Upgrade_Form_Id__c);
        }
        if (this.springboard.settings.Sustainers_Billing_Autologout_Seconds__c != NULL) {
        	this.autologoutSeconds = Integer.valueOf(this.springboard.settings.Sustainers_Billing_Autologout_Seconds__c);
        }
        if (!String.isBlank(this.springboard.settings.Sustainers_HMAC_Excluded_Gateways__c)) {
        	for (String gateway : this.springboard.settings.Sustainers_HMAC_Excluded_Gateways__c.split('\n')) {
        		this.excludedGateways.add(gateway.trim());
        	}
        }
        this.tokenExpiration = Datetime.now().addDays(tokenLifespan);
    }

    global List<Contact> start(Database.BatchableContext context) {
        // Query Contacts to be batched up and processed.
        // We're interested only in Contacts with recurring series as well as Drupal user IDs.
        // To stay within governor limits, we'll pick those with the least-fresh (or non-existant) HMACs first,
        // and skip any with tokens created within the last day.
        List<npe03__Recurring_Donation__c> recurringDonations = new List<npe03__Recurring_Donation__c>([
        	SELECT npe03__Contact__r.Id FROM npe03__Recurring_Donation__c 
        	WHERE npe03__Contact__r.Drupal_User_ID__c != null
//        	AND (
//        		npe03__Contact__r.Billing_Update_Token_Expiration__c = null 
//        		OR npe03__Contact__r.Billing_Update_Token_Expiration__c < :this.hmac.tokenExpiration.addDays(-1)
//    		)
        	ORDER BY npe03__Contact__r.Billing_Update_Token_Expiration__c ASC
        	LIMIT 25000
        ]);
        Set<Id> contactIds = new Set<Id>();
        for (npe03__Recurring_Donation__c recurringDonation : recurringDonations) {
        	contactIds.add(recurringDonation.npe03__Contact__r.Id);
        }
        this.contacts = Database.query('SELECT Drupal_User_ID__c, ' + this.upgradeAmountField + ' FROM Contact WHERE Id IN :contactIds');
        
        // Onwards!
        return this.contacts;
    }
    
    global void execute(Database.BatchableContext context, List<Contact> scope) {
        // First populate the Upgradable_Recurring_Donations__c fields for all Contacts in scope.
        List<Id> contactIds = new List<Id>();
        for (Contact contact : scope) {
            contactIds.add(contact.Id);
        }
        Map<Id, String> contactIdToMasterDonationId = new Map<Id, String>();        // Master DID for the series to be upgraded.
        Map<Id, Id> contactIdToRecurringDonations = new Map<Id, Id>();              // Recurring Donation object to be upgraded.
        Map<Id, Decimal> contactIdToAmount = new Map<Id, Decimal>();                // Recurring donation amount to be upgraded.
        Map<Id, Date> contactIdToLastDate = new Map<Id, Date>();                    // Soonest final scheduled recurring payment.
        Map<Id, String> contactIdToBillingUpdateDonationId = new Map<Id, String>(); // Master DID for the series soonest to need billing updated.
        
        /* Iterate over each contact's recurring donation series. We'll grab some important data off of
         * the first found series, which should be the latest (hence the sort desc).
         * We need these additional data points:
         *  - The master order id. We get this from the first opportunity in the series.
         *  - The amount. This comes from the recurring donation object itself.
         *  - The id of the recurring donation.
         */
        for (npe03__Recurring_Donation__c series : [
            SELECT npe03__Contact__r.Id, npe03__Amount__c, (
            	SELECT order_id__c, CloseDate FROM npe03__Donations__r
            	WHERE (StageName = 'Pledged' OR StageName = 'Posted') AND order_id__c != NULL AND Payment_Gateway__c NOT IN :this.excludedGateways
            	ORDER BY CloseDate ASC
            ) FROM npe03__Recurring_Donation__c
            WHERE npe03__Contact__r.Id IN :contactIds ORDER BY npe03__Date_Established__c DESC
        ]) {
            List<Opportunity> opportunities = series.npe03__Donations__r;
            if (opportunities.size() >= 1) {  // We can't work with series without any orders, so skip 'em.
	            // For Sustainer Upgrade, save only the first (most recent) recurring series for each contact,
	            // and only if it hasn't expired.
	            // @TODO: What about the edge case where the most recent series is expired but an older one isn't?
	            if (contactIdToMasterDonationId.get(series.npe03__Contact__r.Id) == NULL && Date.valueOf(opportunities[opportunities.size() - 1].get('CloseDate')) >= Date.today()) {
	                contactIdToMasterDonationId.put(series.npe03__Contact__r.Id, opportunities[0].order_id__c); 
	                contactIdToRecurringDonations.put(series.npe03__Contact__r.Id, series.Id);
	                contactIdToAmount.put(series.npe03__Contact__r.Id, series.npe03__Amount__c);
	            }
	            // For Billing Update, save the close date and master DID for the series ending the soonest.
	            Date lastCloseDate = Date.valueOf(opportunities[opportunities.size() - 1].get('CloseDate'));
	            if (lastCloseDate >= Date.today() && (
	            	contactIdToLastDate.get(series.npe03__Contact__r.Id) == NULL || lastCloseDate < contactIdToLastDate.get(series.npe03__Contact__r.Id)
            	)) {
	            	contactIdToLastDate.put(series.npe03__Contact__r.Id, lastCloseDate);
	            	contactIdToBillingUpdateDonationId.put(series.npe03__Contact__r.Id, opportunities[0].order_id__c);
	            }
            }
        }

        for (Contact contact : scope) {
            // Set the Contact's upgradable recurring series.
            String masterDonationId = contactIdToMasterDonationId.get(contact.Id);
            contact.Upgradable_Recurring_Donations__c = contactIdToRecurringDonations.get(contact.Id);
            contact.Recurring_Donation_Amount__c = contactIdToAmount.get(contact.Id);
            if (masterDonationId != NULL) {
                contact.Recurring_Donation_Order_Id__c = masterDonationId;
            }
            // Run formula fields so that the upgradeAmountField will update.
            contact.recalculateFormulas();
            // Sustainer Upgrade HMAC is only available for a Contact with an upgradable series and an upgrade amount.
            if (masterDonationId != NULL && contact.get(this.upgradeAmountField) != NULL) {
                // Generate the HMAC sustainer upgrade message for this Contact.
                List<String> parameters = new List<String>();
                parameters.add( String.valueOf(Integer.valueOf(100 * Double.valueOf(contact.get(this.upgradeAmountField)))) );
                parameters.add(masterDonationId);
                if (this.upgradeFormId != NULL) {
                    parameters.add(this.upgradeFormId);
                }
                String message = this.springboard.createHMAC(contact.Drupal_User_ID__c, this.tokenExpiration, 'su', parameters);
                // Sign the message and set the upgrade URL segment and expiration.
                String token = this.springboard.signHMAC(message);
                contact.Upgrade_URL__c = 'hmac/' + EncodingUtil.base64Encode( Blob.valueOf(message) ) + '/' + token;
                contact.Sustainer_Upgrade_Token_Expiration__c = this.tokenExpiration;
            }
            else {
            	// Make sure old HMACs don't hang around.
            	contact.Upgrade_URL__c = null;
            	contact.Sustainer_Upgrade_Token_Expiration__c = null;
            }
            
            // Set the Contact's Billing Update series and end date.
            if (contactIdToBillingUpdateDonationId.get(contact.Id) != NULL) {
	            contact.Billing_Update_Last_Scheduled_Donation__c = contactIdToLastDate.get(contact.Id);
	            contact.Billing_Update_Recurring_Order_ID__c = contactIdToBillingUpdateDonationId.get(contact.Id);
	            // Generate the HMAC billing update message for this Contact.
	            List<String> parameters = new List<String>();
	            parameters.add(EncodingUtil.urlEncode(
	            	'sustainer-series/' + String.valueOf(contactIdToBillingUpdateDonationId.get(contact.Id)) + '/billing',
	            	'utf-8'
	        	));
	        	if (this.autologoutSeconds != NULL) {
	        		parameters.add(String.valueOf(this.autologoutSeconds));
	        	}
                String message = this.springboard.createHMAC(contact.Drupal_User_ID__c, this.tokenExpiration, 'lr', parameters);
	            // Sign the message and set the upgrade URL segment and expiration.
                String token = this.springboard.signHMAC(message);
	            contact.Billing_Update_URL__c = 'hmac/' + EncodingUtil.base64Encode( Blob.valueOf(message) ) + '/' + token;
	            contact.Billing_Update_Token_Expiration__c = this.tokenExpiration;
            }
            else {
            	// Make sure old HMACs don't hang around.
            	contact.Billing_Update_URL__c = null;
            	contact.Billing_Update_Token_Expiration__c = null;
            }
        }
        
        // Save the updated Contacts.
        update scope;
    }
    
    global void finish(Database.BatchableContext context) {
       
    }
}