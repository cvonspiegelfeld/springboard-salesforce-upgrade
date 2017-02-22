trigger ActionsTakenTriggerHandler on sb_Actions_Taken__c (after insert) {
    Map<Id, Integer> contactActionsTaken = new Map<Id, Integer>();
    Map<Id, Integer> contactMessageActionsTaken = new Map<Id, Integer>();
    Map<Id, Integer> contactPetitionsSigned = new Map<Id, Integer>();
    Map<Id, Integer> contactSocialActionsTaken = new Map<Id, Integer>();
    Map<Id, Integer> personalCampaignActionsTaken = new Map<Id, Integer>();
    Map<Id, Integer> personalCampaignPetitionsSigned = new Map<Id, Integer>();
    Map<Id, Integer> personalCampaignSocialActionsTaken = new Map<Id, Integer>();
    Map<Id, Integer> actionActionsTaken = new Map<Id, Integer>();
        
    // Figure out how many actions taken and petitions signatures are going to be added to each Contact and Action.
    for (sb_Actions_Taken__c actionTaken : Trigger.new) {
        // Increment actions taken per Action.
    	actionActionsTaken.put(actionTaken.Action__c, !actionActionsTaken.containsKey(actionTaken.Action__c) ? 
    		1 : actionActionsTaken.get(actionTaken.Action__c) + 1
		);
		// Increment actions taken per Contact, of any/all action types.
    	contactActionsTaken.put(actionTaken.Contact__c, !contactActionsTaken.containsKey(actionTaken.Contact__c) ? 
    		1 : contactActionsTaken.get(actionTaken.Contact__c) + 1
		);
    	// Increment actions taken per Contact per action type.
        if (actionTaken.Action_Type__c == 'Petition') {
        	contactPetitionsSigned.put(actionTaken.Contact__c, !contactPetitionsSigned.containsKey(actionTaken.Contact__c) ? 
        		1 : contactPetitionsSigned.get(actionTaken.Contact__c) + 1
    		);
    		// Increment per P2P Personal Campaign, if one is given.
    		if (actionTaken.P2P_Personal_Campaign__c != NULL) {
	        	personalCampaignPetitionsSigned.put(actionTaken.P2P_Personal_Campaign__c, !personalCampaignPetitionsSigned.containsKey(actionTaken.P2P_Personal_Campaign__c) ? 
	        		1 : personalCampaignPetitionsSigned.get(actionTaken.P2P_Personal_Campaign__c) + 1
	    		);
    		}
       	}
        else if (actionTaken.Action_Type__c == 'Message Action') {
        	contactMessageActionsTaken.put(actionTaken.Contact__c, !contactMessageActionsTaken.containsKey(actionTaken.Contact__c) ? 
        		1 : contactMessageActionsTaken.get(actionTaken.Contact__c) + 1
    		);
    		// Increment per P2P Personal Campaign, if one is given.
    		if (actionTaken.P2P_Personal_Campaign__c != NULL) {
	        	personalCampaignActionsTaken.put(actionTaken.P2P_Personal_Campaign__c, !personalCampaignActionsTaken.containsKey(actionTaken.P2P_Personal_Campaign__c) ? 
	        		1 : personalCampaignActionsTaken.get(actionTaken.P2P_Personal_Campaign__c) + 1
	    		);
    		}
        }
        else if (actionTaken.Action_Type__c == 'Social Action') {
        	contactSocialActionsTaken.put(actionTaken.Contact__c, !contactSocialActionsTaken.containsKey(actionTaken.Contact__c) ? 
        		1 : contactSocialActionsTaken.get(actionTaken.Contact__c) + 1
    		);
    		// Increment per P2P Personal Campaign, if one is given.
    		if (actionTaken.P2P_Personal_Campaign__c != NULL) {
	        	personalCampaignSocialActionsTaken.put(actionTaken.P2P_Personal_Campaign__c, !personalCampaignSocialActionsTaken.containsKey(actionTaken.P2P_Personal_Campaign__c) ? 
	        		1 : personalCampaignSocialActionsTaken.get(actionTaken.P2P_Personal_Campaign__c) + 1
	    		);
    		}
        }
    }

	// Update any involved Contacts.    
    Set<Id> contactIds = new Set<Id>();
    contactIds.addAll(contactActionsTaken.keySet());
    if (!contactIds.isEmpty()) {
        List<Contact> contacts = [SELECT Id, Total_Message_Actions__c, Total_Petitions_Signed__c, Total_Social_Actions__c, Total_Actions_30_Days__c, Last_Action_Date__c, First_Action_Date__c FROM Contact WHERE Id IN : contactIds];
        for (Contact contact: contacts) {
            // First action date.
            if (contact.First_Action_Date__c == NULL) {
                contact.First_Action_Date__c = Date.today();
            }
            // Last action date.
            contact.Last_Action_Date__c = Date.today();
            // Actions taken in the last 30 days.
			// Note that this count is decremented by the ActionsTakenPeriodicRollup batch process, but incrementing it here spares
			// that process having to look at Contacts that haven't had any actions at all recently.
            contact.Total_Actions_30_Days__c = (contact.Total_Actions_30_Days__c == NULL) ?
            	contactActionsTaken.get(contact.Id) : contact.Total_Actions_30_Days__c + contactActionsTaken.get(contact.Id)
        	;
            // Running total of message actions.
            if (contactMessageActionsTaken.containsKey(contact.Id)) {
                contact.Total_Message_Actions__c = (contact.Total_Message_Actions__c == NULL) ?
                	contactMessageActionsTaken.get(contact.Id) : contact.Total_Message_Actions__c + contactMessageActionsTaken.get(contact.Id)
            	;
            }
            // Running total of petitions.
            if (contactPetitionsSigned.containsKey(contact.Id)) {
                contact.Total_Petitions_Signed__c = (contact.Total_Petitions_Signed__c == NULL) ?
                	contactPetitionsSigned.get(contact.Id) : contact.Total_Petitions_Signed__c + contactPetitionsSigned.get(contact.Id)
            	;
            }
            // Running total of social actions.
            if (contactSocialActionsTaken.containsKey(contact.Id)) {
                contact.Total_Social_Actions__c = (contact.Total_Social_Actions__c == NULL) ?
                	contactSocialActionsTaken.get(contact.Id) : contact.Total_Social_Actions__c + contactSocialActionsTaken.get(contact.Id)
            	;
            }
        }
        update contacts;
    }
    
	// Update any involved P2P Personal Campaigns.    
    Set<Id> personalCampaignIds = new Set<Id>();
    personalCampaignIds.addAll(personalCampaignActionsTaken.keySet());
    personalCampaignIds.addAll(personalCampaignPetitionsSigned.keySet());
    personalCampaignIds.addAll(personalCampaignSocialActionsTaken.keySet());
    if (!personalCampaignIds.isEmpty()) {
        List<P2P_Personal_Campaign__c> personalCampaigns = [SELECT Id, Total_Message_Actions__c, Total_Petitions_Signed__c, Total_Social_Actions__c, Last_Action_Date__c, First_Action_Date__c FROM P2P_Personal_Campaign__c WHERE Id IN :personalCampaignIds];
        for (P2P_Personal_Campaign__c campaign: personalCampaigns) {
            // First action date.
            if (campaign.First_Action_Date__c == NULL) {
                campaign.First_Action_Date__c = Date.today();
            }
            // Last action date.
            campaign.Last_Action_Date__c = Date.today();
            // Running total of actions.
            if (personalCampaignActionsTaken.containsKey(campaign.Id)) {
                campaign.Total_Message_Actions__c = (campaign.Total_Message_Actions__c == NULL) ?
                	personalCampaignActionsTaken.get(campaign.Id) : campaign.Total_Message_Actions__c + personalCampaignActionsTaken.get(campaign.Id)
            	;
            }
            // Running total of petitions.
            if (personalCampaignPetitionsSigned.containsKey(campaign.Id)) {
                campaign.Total_Petitions_Signed__c = (campaign.Total_Petitions_Signed__c == NULL) ?
                	personalCampaignPetitionsSigned.get(campaign.Id) : campaign.Total_Petitions_Signed__c + personalCampaignPetitionsSigned.get(campaign.Id)
            	;
            }
            // Running total of social actions.
            if (personalCampaignSocialActionsTaken.containsKey(campaign.Id)) {
                campaign.Total_Social_Actions__c = (campaign.Total_Social_Actions__c == NULL) ?
                	personalCampaignSocialActionsTaken.get(campaign.Id) : campaign.Total_Social_Actions__c + personalCampaignSocialActionsTaken.get(campaign.Id)
            	;
            }
        }
        update personalCampaigns;
    }
    
    // Update any involved Actions.
    Set<Id> actionIds = new Set<Id>();
    actionIds.addAll(actionActionsTaken.keySet());
    if (!actionIds.isEmpty()) {
        List<sb_action__c> actions = [SELECT Id, Actions_Taken__c, Last_Action_Date__c, First_Action_Date__c FROM sb_action__c WHERE Id IN :actionIds];
        for (sb_action__c action : actions) {
            // First action date.
            if (action.First_Action_Date__c == NULL) {
                action.First_Action_Date__c = Date.today();
            }
            // Last action date.
            action.Last_Action_Date__c = Date.today();
            // Running total of actions taken.
            if (actionActionsTaken.containsKey(action.Id)) {
                action.Actions_Taken__c = (action.Actions_Taken__c == NULL) ?
                	actionActionsTaken.get(action.Id) : action.Actions_Taken__c + actionActionsTaken.get(action.Id)
            	;
            }
        }
        update actions;
    }
    
}