trigger SpringboardTrigger_OCDSubscription on One_Click_Donate_Subscription__c (after delete, after insert, after undelete, after update, before delete, before insert, before update) {
    SpringboardTriggerHandler.execute('OCDSubscription');
}