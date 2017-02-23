public with sharing class SB_TESTS_Trigger_Contact extends SpringboardTriggerHandler {
	
	public static String onAfterInsertName;
	public static String onAfterUndeleteName;
	
    public override void onBeforeInsert() {
	    for (Contact c : (Contact[]) Trigger.new) {
	    	c.FirstName = c.FirstName + '-OBI';
	    }
    }
    public override void onAfterInsert() {
	    for (Contact c : (Contact[]) Trigger.new) {
	    	SB_TESTS_Trigger_Contact.onAfterInsertName = c.FirstName;
	    }
    }
	public override void onBeforeUpdate() {
	    for (Contact c : (Contact[]) Trigger.new) {
	    	c.FirstName = c.FirstName + '-OBU';
	    }
	}
	public override void onAfterUpdate() {
	    for (Contact c : (Contact[]) Trigger.new) {
	    	insert new Contact(
	    		FirstName = c.FirstName + '-OAU',
	    		LastName = this.sb.settings.Trigger_Prefixes_Active__c
	    	);
	    }
	}
	public override void onBeforeDelete() {
	    for (Contact c : (Contact[]) Trigger.old) {
	    	insert new Contact(
		    	FirstName = c.FirstName + '-OBD',
	    		LastName = c.LastName
	    	);
	    }
	}
	public override void onAfterDelete() {
	    for (Contact c : (Contact[]) Trigger.old) {
	    	insert new Contact(
		    	FirstName = c.FirstName + '-OAD',
	    		LastName = c.LastName
	    	);
	    }
	}
	public override void onAfterUndelete() {
	    for (Contact c : (Contact[]) Trigger.new) {
	    	SB_TESTS_Trigger_Contact.onAfterUndeleteName = c.FirstName;
	    }
	}
}