global class SB_OCDonate_Scheduler implements Schedulable {
	
	global void execute(SchedulableContext sc) {
		SB_OCDonate_Batch ocdBatch = new SB_OCDonate_Batch();
		Database.executeBatch(ocdBatch, 2000);
	}
}