@isTest
public class ActionsTakenTriggerHandler_TESTS {
    
    @testSetup
	private static void SetupTestData() {
    	Contact contact = new Contact();
        contact.FirstName = 'John';
        contact.LastName = 'Doe';
        contact.email = 'ActionsTakenTriggerHandler_TESTS@example.com';
        insert contact;
        
        P2P_Personal_Campaign__c personalCampaign = new P2P_Personal_Campaign__c();
        personalCampaign.Name = 'John Doe\'s Personal Campaign';
        personalCampaign.P2P_Campaigner__c = contact.Id;
        insert personalCampaign;
	}
    
	@isTest
    private static void ActionsTakenTriggerTESTS() {
        Test.startTest();
        Contact contact = [SELECT Id FROM Contact WHERE Email='ActionsTakenTriggerHandler_TESTS@example.com'];
        P2P_Personal_Campaign__c personalCampaign = [SELECT Id FROM P2P_Personal_Campaign__c WHERE P2P_Campaigner__c=:contact.Id];
        
        sb_action__c  action = new sb_action__c ();
        action.Name = 'Test Action';
        action.Date_Created__c = Date.today();
        insert action;
        
        sb_Actions_Taken__c actionTaken = new sb_Actions_Taken__c();
        actionTaken.Action__c = action.Id;
        actionTaken.Name = 'Action 1';
        actionTaken.Contact__c = contact.Id;
        actionTaken.Action_Type__c = 'Petition';
        insert actionTaken;
        
        sb_Actions_Taken__c socialActionTaken = new sb_Actions_Taken__c();
        socialActionTaken.Action__c = action.Id;
        socialActionTaken.Name = 'Action 2';
        socialActionTaken.Contact__c = contact.Id;
        socialActionTaken.P2P_Personal_Campaign__c = personalCampaign.Id;
        socialActionTaken.Action_Type__c = 'Social Action';
        insert socialActionTaken;
        
        sb_Actions_Taken__c petitionsSigned = new sb_Actions_Taken__c();
        petitionsSigned.Action__c = action.Id;
        petitionsSigned.Name = 'Action 3';
        petitionsSigned.Contact__c = contact.Id;
        petitionsSigned.P2P_Personal_Campaign__c = personalCampaign.Id;
        petitionsSigned.Action_Type__c = 'Petition';
        insert petitionsSigned;

		Test.stopTest();
        
        contact = [SELECT First_Action_Date__c, Last_Action_Date__c, Total_Message_Actions__c, Total_Social_Actions__c, Total_Petitions_Signed__c, Total_Actions_30_Days__c FROM Contact WHERE Id = :contact.Id];
        System.assertEquals(3, contact.Total_Actions_30_Days__c);
        System.assertEquals(2, contact.Total_Petitions_Signed__c);
        System.assertEquals(1, contact.Total_Social_Actions__c);
        System.assertEquals(Date.today(), contact.First_Action_Date__c);
        System.assertEquals(Date.today(), contact.Last_Action_Date__c);

        action = [SELECT Actions_Taken__c, First_Action_Date__c, Last_Action_Date__c FROM sb_action__c WHERE Id = :action.Id];
        System.assertEquals(3, action.Actions_Taken__c);
        System.assertEquals(Date.today(), action.First_Action_Date__c);
        System.assertEquals(Date.today(), action.Last_Action_Date__c);
 
        personalCampaign = [SELECT First_Action_Date__c, Last_Action_Date__c, Total_Message_Actions__c, Total_Social_Actions__c, Total_Petitions_Signed__c FROM P2P_Personal_Campaign__c WHERE P2P_Campaigner__c=:contact.Id];
        System.assertEquals(1, personalCampaign.Total_Petitions_Signed__c);
        System.assertEquals(1, personalCampaign.Total_Social_Actions__c);
        System.assertEquals(Date.today(), personalCampaign.First_Action_Date__c);
        System.assertEquals(Date.today(), personalCampaign.Last_Action_Date__c);
 
    }
    
	@isTest
    private static void ActionsTakenPeriodicRollupTests() {
        Contact contact = [SELECT Id FROM Contact WHERE Email='ActionsTakenTriggerHandler_TESTS@example.com'];

        Test.startTest();
        
        sb_action__c  action = new sb_action__c ();
        action.Name = 'Test Action';
        action.Date_Created__c = Date.today();
        insert action;
        
        sb_Actions_Taken__c actionTaken = new sb_Actions_Taken__c();
        actionTaken.Action__c = action.Id;
        actionTaken.Name = 'Action 1';
        actionTaken.Contact__c = contact.Id;
        actionTaken.Action_Type__c = 'Petition';
        actionTaken.Date_of_Action__c = Date.today().addDays(-4);
        insert actionTaken;
        
        sb_Actions_Taken__c socialActionTaken = new sb_Actions_Taken__c();
        socialActionTaken.Action__c = action.Id;
        socialActionTaken.Name = 'Action 2';
        socialActionTaken.Contact__c = contact.Id;
        socialActionTaken.Action_Type__c = 'Social Action';
        socialActionTaken.Date_of_Action__c = Date.today().addDays(-40);
        insert socialActionTaken;
        
        // Run a mock scheduled batch.
		ActionsTakenPeriodicRollupScheduler scheduler = new ActionsTakenPeriodicRollupScheduler();
		SchedulableContext context;
		scheduler.execute(context);
        
		Test.stopTest();
        
        // Only the action within 30 days should be counted after the batch has run.
        contact = [SELECT Total_Actions_30_Days__c FROM Contact WHERE Id = :contact.Id];
        System.assertEquals(1, contact.Total_Actions_30_Days__c);
    }
}