global class SB_Sustainers_Scheduler implements Schedulable {
	
	global void execute(SchedulableContext sc) {
		// Contact HMACs
		SB_Sustainers_Batch batch = new SB_Sustainers_Batch();
		Database.executeBatch(batch, 100);
	}
}