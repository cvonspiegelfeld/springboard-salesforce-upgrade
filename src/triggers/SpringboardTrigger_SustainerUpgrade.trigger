trigger SpringboardTrigger_SustainerUpgrade on Sustainer_Upgrade__c (after delete, after insert, after undelete, after update, before delete, before insert, before update) {
    SpringboardTriggerHandler.execute('SustainerUpgrade');
}