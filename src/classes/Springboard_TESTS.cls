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
private class Springboard_TESTS {

	static testMethod void MissingEncryptorKey() {
        Springboard_Settings__c testSettings = new Springboard_Settings__c(Name = 'Springboard_TESTS');
        testSettings.Encryptor_Key__c = null;
        insert testSettings;
        
		// Try to encrypt a string.
		Springboard springboard = new Springboard('Springboard_TESTS');
		String failedEncryption = springboard.encrypt('This should fail.');
		
		// Assert we got the failure string.
		System.assertEquals('Unable to encrypt string because an Encryptor Key or IV setting is missing.', failedEncryption);
	}
	
	static testMethod void EncryptString() {
        Springboard_Settings__c testSettings = new Springboard_Settings__c(Name = 'Springboard_TESTS');
        testSettings.Encryptor_Key__c = '12345678901234561234567890123456';
        testSettings.Encryptor_IV__c = '1234567890123456';
        insert testSettings;
        
		// Encrypt a string.
		Springboard springboard = new Springboard('Springboard_TESTS');
		String encrypted = springboard.encrypt('The rain in Spain stays almost invariably in the hills.');
		
		// Assert encryption was successful.
		System.assertEquals('d4tk8cgMov0BAh9E%2BoPMGfEdzEiubPpgFxNRn0ShZjHUN622FzC9WSv%2BIP4lASdE2PpEaAQCx96dRXDBY2XwNw%3D%3D', encrypted);
	}

    static testMethod void generateHMAC() {
    	// Set encryption key.
        Springboard_Settings__c testSettings = new Springboard_Settings__c(Name = 'Springboard_TESTS');
        testSettings.Encryptor_IV__c = '22SIRITmX9L7irSJ';
        testSettings.Encryptor_Key__c = 'SQgOCb34r2i3tfMvPZDkkLMVwqD90g9S';
        insert testSettings;
        
        // Create the HMAC.
        Test.startTest();
        Springboard sb = new Springboard('Springboard_TESTS');
        String[] params = new String[]{'p1', 'p2'};
        String message = sb.createHMAC('1234', Datetime.newInstanceGMT(1979, 1, 7, 0, 0, 0), 'jackson', params);
		String token = sb.signHMAC(message);
        String messageExpected = '1234.284515200.jackson.p1.p2';
        String tokenExpected = 'typ8HD3sPRSk66h6rSMgqAF__9hnlRxUk7M0eO1E2DY';
        Test.stopTest();

		// Assert results are as expected.        
        System.assertEquals(messageExpected, message);
        System.assertEquals(tokenExpected, token);
    }
    
    static testMethod void triggerHandler() {
    	// Set encryption key.
        Springboard_Settings__c testSettings = new Springboard_Settings__c(Name = 'Springboard_TESTS');
        testSettings.Trigger_Prefixes_Active__c = 'TESTS';
        insert testSettings;
        
        // Create the HMAC.
        Test.startTest();
        Springboard sb = new Springboard('Springboard_TESTS');
    	Contact testContact = new Contact(
    		FirstName = 'Test',
    		LastName = 'Tester'
    	);
    	insert testContact;
    	update testContact;
    	delete testContact;
    	undelete testContact;
    	Test.stopTest();
    	
    	// Assertions
    	System.assertEquals('Test-OBU-OAD-OBI', SB_TESTS_Trigger_Contact.onAfterInsertName);
    	System.assertEquals('Test-OBU', SB_TESTS_Trigger_Contact.onAfterUndeleteName);
    	Contact testContact2 = [SELECT FirstName, LastName FROM Contact WHERE LastName='TESTS'];  // There's only one update, so there should only be one of these.
    	System.assertEquals('Test-OBU-OAU-OBI', testContact2.FirstName);
    	Contact testContact3 = [SELECT FirstName, LastName FROM Contact WHERE FirstName='Test-OBU-OBD-OBI'];
    	System.assertNotEquals(null, testContact3);
    }

}