global with sharing class ActionsTakenPeriodicRollup implements Database.Batchable<SObject>, Database.Stateful {

	global List<Contact> contacts;
	
	global ActionsTakenPeriodicRollup(List<Contact> contacts) {
		this.contacts = contacts;
	}

    global List<Contact> start(Database.BatchableContext context) {
        return this.contacts;
    }
    
    global void execute(Database.BatchableContext context, List<Contact> scope) {
    	Set<Id> contactIds = new Set<Id>();
		for (Contact contact : scope) {
			contactIds.add(contact.Id);
		}
		Map<Id, AggregateResult> contactActionCounts = new Map<Id, AggregateResult>([
			SELECT Contact__r.Id, COUNT(Id) FROM sb_Actions_Taken__c 
			WHERE Contact__c IN :contactIds AND Date_of_Action__c > :DateTime.now().addDays(-30)
			GROUP BY Contact__r.Id
		]);
		AggregateResult actionCount;
		for (Contact contact : scope) {
			actionCount = contactActionCounts.get(contact.Id);
			contact.Total_Actions_30_Days__c = (actionCount == NULL) ? 0 : Integer.valueOf(actionCount.get('expr0'));
		}
		
		// Save the updated Contacts.
		update scope;
    }
    
    global void finish(Database.BatchableContext context) {
       
    }
}