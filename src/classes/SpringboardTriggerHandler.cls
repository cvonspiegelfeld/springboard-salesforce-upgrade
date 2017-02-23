public abstract class SpringboardTriggerHandler {
	public Springboard sb;
	
	public static void execute(String objectType) {
		// If we're testing and no Springboard Settings profile is set, then there's no Springboard trigger logic to execute.
		if (Test.isRunningTest() && !Springboard.settingsAreLoaded()) { return; }
		Springboard sb = new Springboard();
        // What trigger prefixes are active?
        String[] triggerPrefixes = new List<String>();
        if (!String.isBlank(sb.settings.Trigger_Prefixes_Active__c)) {
        	for (String prefix : sb.settings.Trigger_Prefixes_Active__c.split('\n')) {
        		triggerPrefixes.add(prefix.trim());
        	}
        }
		// Iterate over trigger prefixes looking for trigger handler classes for this object type.
		for (String triggerPrefix : triggerPrefixes) {
			Type handlerType = Type.forName('SB_' + triggerPrefix + '_Trigger_' + objectType);
			if (handlerType != null) {
				SpringboardTriggerHandler handler = (SpringboardTriggerHandler) handlerType.newInstance();
				handler.sb = sb;
				// Invoke the appropriate operation's method on the handler.
				if (Trigger.isBefore) {
					if (Trigger.isInsert) { handler.onBeforeInsert(); } else
					if (Trigger.isUpdate) { handler.onBeforeUpdate(); } else
					if (Trigger.isDelete) { handler.onBeforeDelete(); }
				} else if (Trigger.isAfter) {
					if (Trigger.isInsert) { handler.onAfterInsert(); } else
					if (Trigger.isUpdate) { handler.onAfterUpdate(); } else
					if (Trigger.isDelete) { handler.onAfterDelete(); } else
					if (Trigger.isUndelete) { handler.onAfterUndelete(); }
				}
			}
		}
	}
	
    public virtual void onBeforeInsert() { }
    public virtual void onAfterInsert() { }
	public virtual void onBeforeUpdate() { }
	public virtual void onAfterUpdate() { }
	public virtual void onBeforeDelete() { }
	public virtual void onAfterDelete() { }
	public virtual void onAfterUndelete() { }
	
}