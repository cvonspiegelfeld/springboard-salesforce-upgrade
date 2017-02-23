@isTest
public class SB_Sustainers_TESTS {

    @testSetup
    private static void SetupTestData() {
        Springboard_Settings__c testSettings = new Springboard_Settings__c(Name = 'SB_Sustainers_TESTS');
        testSettings.Sustainers_HMAC_Token_Lifespan__c = 30;
        testSettings.Encryptor_IV__c = '22SIRITmX9L7irSJ';
        testSettings.Encryptor_Key__c = 'SQgOCb34r2i3tfMvPZDkkLMVwqD90g9S';
        testSettings.Trigger_Prefixes_Active__c = 'Sustainers';
        insert testSettings;
    }

    private static testMethod void TokensTestBatch() {
        // Set-up: custom settings.
        Springboard springboard = new Springboard('SB_Sustainers_TESTS');
        springboard.settings.Sustainers_Upgrade_Amount_Field__c = 'Recurring_Donation_Amount__c';  // But, you protest, this is the wrong field! Doesn't matter. It's a field we can set.
        springboard.settings.Sustainers_Upgrade_Form_Id__c = 98765;
        springboard.settings.Sustainers_Billing_Autologout_Seconds__c = 120;
        springboard.settings.Sustainers_HMAC_Excluded_Gateways__c = 'EXCLUDED_GATEWAY_1\nEXCLUDED_GATEWAY_2';
        upsert springboard.settings;

        // Set-up: Contact to upsell and upgrade.
        Contact testContact = new Contact(
            FirstName = 'Test Contact',
            LastName = 'SB_Sustainers_TESTS',
            Drupal_User_ID__c = '12345'
        );
        insert testContact;
        
        // Create a recurring donation for this contact. The amount in npe03__Amount__c should get
        // written over to the Recurring_Donation_Amount__c field on the contact object.
        npe03__Recurring_Donation__c recurringSeries = new npe03__Recurring_Donation__c(
            npe03__Contact__c = testContact.Id,
            npe03__Date_Established__c = Date.today(),
            npe03__Amount__c = 22.22
        );
        insert recurringSeries;
        
        // Create some opportunities in the recurring series.
        List<Opportunity> donations = new List<Opportunity>();
        for (integer i = 1; i <= 10; i++) {
            Opportunity donation = new Opportunity();
            donation.order_id__c = string.valueOf(i + 100);
            donation.Name = 'Donation ' + String.valueOf(100 + i);
            donation.Amount = 22.22;
            donation.npe03__Recurring_Donation__c = recurringSeries.Id;
            donation.AccountId = testContact.AccountId;
            donation.StageName = 'Pledged';
            donation.CloseDate = Date.today().addMonths(i);
            donations.add(donation);
        }
        insert donations;
        
        // Create an older recurring donation for this contact. The master order ID should get written
        // to Billing_Update_Recurring_Order_ID__c, and the series's last donation's CloseDate should
        // get written to Billing_Update_Last_Scheduled_Donation__c.
        npe03__Recurring_Donation__c oldRecurringSeries = new npe03__Recurring_Donation__c(
            npe03__Contact__c = testContact.Id,
            npe03__Date_Established__c = Date.today().addMonths(-1),  // This series was begun a month ago.
            npe03__Amount__c = 11.11
        );
        insert oldRecurringSeries;
        List<Opportunity> oldDonations = new List<Opportunity>();
        for (integer i = 1; i <= 4; i++) {  // This series is only four months long (i.e., card expires soon).
            Opportunity oldDonation = new Opportunity();
            oldDonation.order_id__c = string.valueOf(50 + i);
            oldDonation.Name = 'Donation ' + String.valueOf(i);
            oldDonation.Amount = 11.11;
            oldDonation.npe03__Recurring_Donation__c = oldRecurringSeries.Id;
            oldDonation.AccountId = testContact.AccountId;
            oldDonation.StageName = 'Pledged';
            oldDonation.CloseDate = Date.today().addMonths(i - 1);
            oldDonation.Payment_Gateway__c = 'NOT_AN_EXCLUDED_GATEWAY';
            oldDonations.add(oldDonation);
        }
        insert oldDonations;

        // Create an even older recurring donation. Give it an excluded payment gateway, so it shouldn't
        // show up on the Contact at all.
        npe03__Recurring_Donation__c olderRecurringSeries = new npe03__Recurring_Donation__c(
            npe03__Contact__c = testContact.Id,
            npe03__Date_Established__c = Date.today().addMonths(-2),  // This series was begun two months ago.
            npe03__Amount__c = 5.55
        );
        insert olderRecurringSeries;
        List<Opportunity> olderDonations = new List<Opportunity>();
        for (integer i = 1; i <= 4; i++) {  // This series is only three months long.
            Opportunity olderDonation = new Opportunity();
            olderDonation.order_id__c = string.valueOf(10 + i);
            olderDonation.Name = 'Donation ' + String.valueOf(i);
            olderDonation.Amount = 5.55;
            olderDonation.npe03__Recurring_Donation__c = olderRecurringSeries.Id;
            olderDonation.AccountId = testContact.AccountId;
            olderDonation.StageName = 'Pledged';
            olderDonation.CloseDate = Date.today().addMonths(i - 2);
            olderDonation.Payment_Gateway__c = 'EXCLUDED_GATEWAY_2';
            olderDonations.add(olderDonation);
        }
        insert olderDonations;

        Test.startTest();
        SB_Sustainers_Scheduler scheduler = new SB_Sustainers_Scheduler();
        SchedulableContext context;
        scheduler.execute(context);
        Test.stopTest();
        
        // Query the test Contact and verify the upgrade URL and expiry.
        Contact contact = [
        	SELECT Upgrade_URL__c, Sustainer_Upgrade_Token_Expiration__c, Upgradable_Recurring_Donations__r.Id, Billing_Update_Recurring_Order_ID__c, 
        		Billing_Update_Last_Scheduled_Donation__c, Billing_Update_URL__c, Billing_Update_Token_Expiration__c
        	FROM Contact WHERE LastName='SB_Sustainers_TESTS'
    	];

		// Sustainer Upgrade assertions.
        System.assertEquals(contact.Upgradable_Recurring_Donations__r.Id, recurringSeries.Id);
        String expectedMessage = '12345.' + String.valueOf(contact.Sustainer_Upgrade_Token_Expiration__c.getTime() / 1000) + '.su.2222.101.98765';
        String expectedToken = springboard.signHMAC(expectedMessage);
        String expectedUrl = 'hmac/' + EncodingUtil.base64Encode( Blob.valueOf(expectedMessage) ) + '/' + expectedToken;
        System.assertEquals(contact.Upgrade_URL__c, expectedUrl);
        System.assertEquals(contact.Sustainer_Upgrade_Token_Expiration__c.date(), Date.today().addDays(30));  // Make sure our custom setting overrode the hardwired default.
        
        // Billing Update assertions.
        System.assertEquals(contact.Billing_Update_Last_Scheduled_Donation__c, Date.today().addMonths(3));  // This should be the CloseDate of the last donation in the older series.
        expectedMessage = '12345.' + String.valueOf(contact.Billing_Update_Token_Expiration__c.getTime() / 1000) + '.lr.sustainer-series%2F51%2Fbilling.120';
        expectedToken = springboard.signHMAC(expectedMessage);
        expectedUrl = 'hmac/' + EncodingUtil.base64Encode( Blob.valueOf(expectedMessage) ) + '/' + expectedToken;
        System.assertEquals(contact.Billing_Update_URL__c, expectedUrl);
        System.assertEquals(contact.Billing_Update_Token_Expiration__c.date(), Date.today().addDays(30));  // Make sure our custom setting overrode the hardwired default.
    }
    
    private static testMethod void newSustainerUpgrades() {
        Springboard springboard = new Springboard('SB_Sustainers_TESTS');

        // Create a donor and recurring donation.
        Contact donor = new Contact(
        	FirstName = 'Tester',
        	LastName = 'SustainersUpgraded_TESTS'
        );
        insert donor;
        
        npe03__Recurring_Donation__c series = new npe03__Recurring_Donation__c(
        	npe03__Contact__c = donor.Id,
            npe03__Date_Established__c = Date.today().addMonths(-10),  // This series was begun ten months ago.
            npe03__Amount__c = 11.11
        );
        insert series;
        
        // Create two upgrades for the one donor with different timestamps.
        List<Sustainer_Upgrade__c> upgrades = new List<Sustainer_Upgrade__c>();
        upgrades.add(new Sustainer_Upgrade__c(
        	Contact__c = donor.Id,
        	Failure_Flag__c = 'The first upgrade attempt failed for some reason.',
        	Recurring_Donations__c = series.Id
        ));
        upgrades.get(0).Timestamp__c = DateTime.now().addDays(-1);

		DateTime successTimestamp = DateTime.now();
        upgrades.add(new Sustainer_Upgrade__c(
        	Contact__c = donor.Id,
        	Timestamp__c = successTimestamp,
        	Recurring_Donations__c = series.Id
        ));
        
        // Insert the upgrade objects to run the trigger.
        Test.startTest();
        insert upgrades;
        Test.stopTest();
        
        // Confirm the contact was updated correctly by the trigger.
        donor = [
        	SELECT Last_Sustainer_Upgrade_Date__c, Last_Sustainer_Upgrade_Successful__c
        	FROM Contact WHERE Id = :donor.Id
    	];
        System.assertEquals(donor.Last_Sustainer_Upgrade_Date__c, successTimestamp);
        System.assertEquals(donor.Last_Sustainer_Upgrade_Successful__c, true);
    }
    
}