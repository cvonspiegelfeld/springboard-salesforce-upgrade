/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an organization are executed whenever Apex code is deployed
 * to a production organization to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production organization. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the organization size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest
private class SB_OCDonate_TESTS {

    @testSetup
    private static void SetupTestData() {
        Springboard_Settings__c testSettings = new Springboard_Settings__c(Name = 'SB_OCDonate_TESTS');
        testSettings.OCDonate_HMAC_Token_Lifespan__c = 30;
        testSettings.Encryptor_IV__c = '22SIRITmX9L7irSJ';
        testSettings.Encryptor_Key__c = 'SQgOCb34r2i3tfMvPZDkkLMVwqD90g9S';
        testSettings.Trigger_Prefixes_Active__c = 'OCDonate';
        insert testSettings;
    }

    private static testMethod void TestBatch() {
        Springboard springboard = new Springboard('SB_OCDonate_TESTS');

        // Set-up: Contact to be One Click Donate subscriber and donor.
        Contact testContact = new Contact(
            FirstName = 'Test Contact',
            LastName = 'SB_OCDonate_TESTS',
            Drupal_User_ID__c = '12345'
        );
        insert testContact;
        
        // Create an original donation for the test contact.
        Opportunity donation = new Opportunity(
        	Name = 'Test Donation 1',
        	order_id__c = '54321',
        	Amount = 33.33,
        	AccountId = testContact.AccountId,
        	StageName = 'Posted'
        );
        donation.CloseDate = Date.today().addMonths(-1);
        insert donation;

        // Create a default One Click Donate subscription for the test contact.
        One_Click_Donate_Subscription__c subscription1 = new One_Click_Donate_Subscription__c(
        	Contact__c = testContact.Id,
        	Donation__c = donation.Id,
        	Payment_Token_Id__c = '98765',
        	Payment_Token__c = '0123456789|9876543210',
        	Payment_Gateway__c = 'OCD_PAYMENT_GATEWAY',
        	CC_Last_4__c = '1234',
        	Default_Payment_Method__c = true
        );
        subscription1.Activation_Date__c = Date.today().addMonths(-1);
        subscription1.CC_Exp_Month__c = Date.today().addMonths(1).month();
        subscription1.CC_Exp_Year__c = Date.today().addMonths(1).year();
        insert subscription1;

        // Create another One Click Donate subscription for the test contact.
        One_Click_Donate_Subscription__c subscription2 = new One_Click_Donate_Subscription__c(
        	Contact__c = testContact.Id,
        	Donation__c = donation.Id,
        	Payment_Token_Id__c = '12345',
        	Payment_Token__c = '9876543210|0123456789',
        	CC_Last_4__c = '9876'
        );
        subscription2.Activation_Date__c = Date.today().addMonths(-11);
        subscription2.CC_Exp_Month__c = Date.today().addMonths(-1).month();
        subscription2.CC_Exp_Year__c = Date.today().addMonths(-1).year();
        insert subscription2;

		// Run the batch job to generate HMACs.
        Test.startTest();
        SB_OCDonate_Scheduler scheduler = new SB_OCDonate_Scheduler();
        SchedulableContext context;
        scheduler.execute(context);
        Test.stopTest();
        
        // Query the test contact's One Click Donate Subscription and verify the HMAC URL and expiry.
        testContact = [
        	SELECT OCDonate_Opt_In_Date__c, OCDonate_Opt_Out_Date__c, OCDonate_CC_Last_4__c, 
        		OCDonate_Payment_Gateway__c, OCDonate_URL__c, OCDonate_Token_Expiration__c
        	FROM Contact WHERE LastName='SB_OCDonate_TESTS'
    	];
        String expectedMessage = '12345.' + String.valueOf(testContact.OCDonate_Token_Expiration__c.getTime() / 1000) + '.ocd.98765';
        String expectedToken = springboard.signHMAC(expectedMessage);
        String expectedUrl = 'hmac/' + EncodingUtil.base64Encode( Blob.valueOf(expectedMessage) ) + '/' + expectedToken;
        System.assertEquals(testContact.OCDonate_CC_Last_4__c, '1234');
        System.assertEquals(testContact.OCDonate_URL__c, expectedUrl);
        System.assertEquals(testContact.OCDonate_Payment_Gateway__c, 'OCD_PAYMENT_GATEWAY');
        System.assertEquals(testContact.OCDonate_Token_Expiration__c.date(), Date.today().addDays(30));  // Make sure our custom setting overrode the hardwired default.
    }
    
    private static testMethod void TestOptOut() {
        Springboard springboard = new Springboard('SB_OCDonate_TESTS');

        // First contact to be One Click Donate subscriber and donor.
        Contact testContact1 = new Contact(
            FirstName = 'Test Contact 1',
            LastName = 'SB_OCDonate_TESTS',
            Drupal_User_ID__c = '12345'
        );
        insert testContact1;
        
        // Create an original donation for the first test contact.
        Opportunity donation1 = new Opportunity(
        	Name = 'SB_OCDonate_TESTS Donation 1',
        	order_id__c = '54321',
        	Amount = 33.33,
        	AccountId = testContact1.AccountId,
        	StageName = 'Posted'
        );
        donation1.CloseDate = Date.today().addMonths(-1);
        insert donation1;

        // Create a default One Click Donate subscription for the first test contact, with an expired card.
        One_Click_Donate_Subscription__c subscription1 = new One_Click_Donate_Subscription__c(
        	Contact__c = testContact1.Id,
        	Donation__c = donation1.Id,
        	Payment_Token_Id__c = '98764',
        	Payment_Token__c = '0123456788|9876543209',
        	CC_Last_4__c = '1233',
        	Default_Payment_Method__c = true
        );
        subscription1.Activation_Date__c = Date.today().addMonths(-1);
        subscription1.CC_Exp_Month__c = Date.today().addMonths(-1).month();
        subscription1.CC_Exp_Year__c = Date.today().addMonths(-1).year();
        insert subscription1;

        // Create another donation for the first test contact.
        Opportunity donation2 = new Opportunity(
        	Name = 'SB_OCDonate_TESTS Donation 2',
        	order_id__c = '54322',
        	Amount = 33.34,
        	AccountId = testContact1.AccountId,
        	StageName = 'Posted'
        );
        donation2.CloseDate = Date.today().addMonths(-1);
        insert donation2;

        // Create a default One Click Donate subscription for the first test contact, with a current card.
        One_Click_Donate_Subscription__c subscription2 = new One_Click_Donate_Subscription__c(
        	Contact__c = testContact1.Id,
        	Donation__c = donation2.Id,
        	Payment_Token_Id__c = '98765',
        	Payment_Token__c = '0123456789|9876543210',
        	CC_Last_4__c = '1234',
        	Default_Payment_Method__c = true
        );
        subscription2.Activation_Date__c = Date.today().addMonths(-1);
        subscription2.CC_Exp_Month__c = Date.today().addMonths(1).month();
        subscription2.CC_Exp_Year__c = Date.today().addMonths(1).year();
        insert subscription2;

        // Create another donor, donation and One Click Donate subscription.
        Contact testContact2 = new Contact(
            FirstName = 'Test Contact 2',
            LastName = 'SB_OCDonate_TESTS',
            Drupal_User_ID__c = '123456'
        );
        insert testContact2;
        
        // Create an original donation for the second test contact.
        Opportunity donation3 = new Opportunity(
        	Name = 'SB_OCDonate_TESTS Donation 3',
        	order_id__c = '543210',
        	Amount = 44.44,
        	AccountId = testContact2.AccountId,
        	StageName = 'Posted'
        );
        donation3.CloseDate = Date.today().addDays(-1);
        insert donation3;

        One_Click_Donate_Subscription__c subscription3 = new One_Click_Donate_Subscription__c(
        	Contact__c = testContact2.Id,
        	Donation__c = donation3.Id,
        	Payment_Token_Id__c = '12345',
        	Payment_Token__c = '9876543210|0123456789',
        	CC_Last_4__c = '9876',
        	Default_Payment_Method__c = true
        );
        subscription3.Activation_Date__c = Date.today().addDays(-1);
        insert subscription3;

		// Run batch to generate HMACs, then opt out of the second subscription.
		Test.startTest();
        SB_OCDonate_Scheduler scheduler = new SB_OCDonate_Scheduler();
        SchedulableContext context;
        scheduler.execute(context);
        subscription3 = [SELECT Id, Deactivation_Date__c FROM One_Click_Donate_Subscription__c WHERE Id=:subscription3.Id];
        subscription3.Deactivation_Date__c = Date.today();
        subscription3.Default_Payment_Method__c = false;
        update subscription3;
        Test.stopTest();
        
        // Query the test contact's One Click Donate Subscription and verify the HMAC URL and expiry.
        testContact1 = [
        	SELECT OCDonate_Active_Subscription__c, OCDonate_URL__c, OCDonate_Token_Expiration__c
        	FROM Contact WHERE LastName='SB_OCDonate_TESTS' AND FirstName='Test Contact 1'
    	];
        testContact2 = [
        	SELECT OCDonate_Active_Subscription__c, OCDonate_URL__c, OCDonate_Token_Expiration__c
        	FROM Contact WHERE LastName='SB_OCDonate_TESTS' AND FirstName='Test Contact 2'
    	];
        System.assertNotEquals(null, testContact1.OCDonate_URL__c);
        System.assertEquals(subscription2.Id, testContact1.OCDonate_Active_Subscription__c);
        System.assertEquals(null, testContact2.OCDonate_URL__c);
        System.assertEquals(null, testContact2.OCDonate_Active_Subscription__c);
    }
    
    private static testMethod void TestExpire() {
        Springboard springboard = new Springboard('SB_OCDonate_TESTS');

        // Contact to be One Click Donate subscriber and donor.
        Contact testContact = new Contact(
            FirstName = 'Test Contact',
            LastName = 'SB_OCDonate_TESTS',
            Drupal_User_ID__c = '12345',
            OCDonate_CC_Last_4__c = '1234'  // This should wind up getting blanked.
        );
        insert testContact;
        
        // Create an original donation for the first test contact.
        Opportunity donation = new Opportunity(
        	Name = 'SB_OCDonate_TESTS Donation',
        	order_id__c = '54321',
        	Amount = 33.33,
        	AccountId = testContact.AccountId,
        	StageName = 'Posted'
        );
        donation.CloseDate = Date.today().addMonths(-2);
        insert donation;

        // Create a default One Click Donate subscription with an expired card.
        One_Click_Donate_Subscription__c subscription = new One_Click_Donate_Subscription__c(
        	Contact__c = testContact.Id,
        	Donation__c = donation.Id,
        	Payment_Token_Id__c = '98764',
        	Payment_Token__c = '0123456788|9876543209',
        	CC_Last_4__c = '1234',
        	Default_Payment_Method__c = true  // This should wind up false.
        );
        subscription.Activation_Date__c = Date.today().addMonths(-2);
        subscription.CC_Exp_Month__c = Date.today().addMonths(-1).month();
        subscription.CC_Exp_Year__c = Date.today().addMonths(-1).year();
        insert subscription;

		// Run batch to generate HMACs, although we shouldn't get any.
		Test.startTest();
        SB_OCDonate_Scheduler scheduler = new SB_OCDonate_Scheduler();
        SchedulableContext context;
        scheduler.execute(context);
        Test.stopTest();
        
        // Query the expired subscription and verify it is no longer marked default.
        subscription = [SELECT Id, Default_Payment_Method__c FROM One_Click_Donate_Subscription__c WHERE Id=:subscription.Id];
        System.assertEquals(false, subscription.Default_Payment_Method__c);
        
        // Query the test contact and verify it has no OCDonate info or HMAC.
        testContact = [
        	SELECT OCDonate_CC_Last_4__c, OCDonate_URL__c
        	FROM Contact WHERE LastName='SB_OCDonate_TESTS' AND FirstName='Test Contact'
    	];
        System.assertEquals(null, testContact.OCDonate_URL__c);
        System.assertEquals(null, testContact.OCDonate_CC_Last_4__c);
    }
    
}