global class ActionsTakenPeriodicRollupScheduler implements Schedulable {
	global void execute(SchedulableContext sc) {
		List<Contact> contacts = [SELECT Id FROM Contact WHERE Total_Actions_30_Days__c > 0];
		ActionsTakenPeriodicRollup batch = new ActionsTakenPeriodicRollup(contacts);
		Database.executeBatch(batch, 30);
	}
}