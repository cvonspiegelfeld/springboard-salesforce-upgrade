public with sharing class SB_Sustainers_Trigger_SustainerUpgrade extends SpringboardTriggerHandler {
	
	public override void onAfterInsert() {
	    Map<Id, DateTime> contactIdToLatestTimestamp = new Map<Id, DateTime>();
	    Map<Id, Boolean> contactIdToLatestSuccess = new Map<Id, Boolean>();
	    for (Sustainer_Upgrade__c upgrade : (Sustainer_Upgrade__c[]) Trigger.new) {
	        if (upgrade.Contact__c != NULL && (contactIdToLatestTimestamp.get(upgrade.Contact__c) == NULL 
	            || contactIdToLatestTimestamp.get(upgrade.Contact__c) < upgrade.Timestamp__c)
	        ) {
	            contactIdToLatestTimestamp.put(upgrade.Contact__c, upgrade.Timestamp__c);
	            contactIdToLatestSuccess.put(upgrade.Contact__c, String.isBlank(upgrade.Failure_Flag__c));
	        }
	    }
	    if (contactIdToLatestTimestamp.size() > 0) {
	        // Query and update the relevant Contact records.
	        List<Contact> contacts = [
	            SELECT Last_Sustainer_Upgrade_Date__c, Last_Sustainer_Upgrade_Successful__c
	            FROM Contact WHERE Id IN :contactIdToLatestTimestamp.keySet() 
	        ];
	        for (Contact contact : contacts) {
	            if (contact.Last_Sustainer_Upgrade_Date__c == null 
	                || contactIdToLatestTimestamp.get(contact.Id) > contact.Last_Sustainer_Upgrade_Date__c
	            ) {
	                contact.Last_Sustainer_Upgrade_Date__c = contactIdToLatestTimestamp.get(contact.Id);
	                contact.Last_Sustainer_Upgrade_Successful__c = contactIdToLatestSuccess.get(contact.Id);
	            }
	        }
	        update contacts;
	    }
	}
}