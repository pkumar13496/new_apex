global class CLS_ApprovalInvokeAction {
    
    webservice static String ApprovalInvokeAction(Id appId){
        try{
            
            Pricing_Detail_Subcategory__c offer = [SELECT Id,Name,
                                                   Is_Valid__c,
                                                   Type__c,
                                                   Is_Selected__c,
                                                   CASystemDecision__c,
                                                   Pricing_Detail__c,
                                                   Pricing_Detail__r.genesis__Application__c,
                                                   Pricing_Detail__r.genesis__Application__r.genesis__Status__c,
                                                   Pricing_Detail__r.genesis__Type__c
                                                   FROM Pricing_Detail_Subcategory__c 
                                                   WHERE Pricing_Detail__r.genesis__Application__c = :appId
                                                   AND Is_Selected__c = true ];

            
            Boolean isHOOverridePending = false;
            if(offer != null){
                Decision_Reason__c[] decisionReasonList = [SELECT Id,CustomStatus__c,HO_Override__c,Latest_Decision_Reason__c FROM Decision_Reason__c 
                                                           WHERE Pricing_Detail__c = :offer.Pricing_Detail__c AND Latest_Decision_Reason__c = true ];
                
                for(Decision_Reason__c decisionReason : decisionReasonList){
                    if(decisionReason.CustomStatus__c != null || !String.isEmpty(decisionReason.CustomStatus__c)){
                        if((decisionReason.CustomStatus__c.equalsIgnoreCase('caution') ||  decisionReason.CustomStatus__c.equalsIgnoreCase('fail')) && !decisionReason.HO_Override__c){
                            isHOOverridePending = true;
                        }
                    }
                }
                
                System.debug('isHOOverridePending: ' + isHOOverridePending);
                
                if(isHOOverridePending){
                    return 'Please Override Decision Reason.';
                }                
            }else{
                return 'Please Select an Offer.';
            }                       
            
            genesis__Applications__c apprecord = new genesis__Applications__c(Id=appId);
            if(offer != null){
                if(offer.Pricing_Detail__r.genesis__Application__r.genesis__Status__c == 'CLAO IN PROCESS' 
                   && offer.Pricing_Detail__r.genesis__Type__c == 'SPL Offer'){
                       apprecord.genesis__Status__c = 'CLAO INITIAL APPROVAL';
                   } 
                
                else if(offer.Pricing_Detail__r.genesis__Application__r.genesis__Status__c == 'CLAO IN PROCESS' 
                        && offer.Pricing_Detail__r.genesis__Type__c == 'UPL Offer' ){
                            String missingFields = CLS_FieldValidation.ValidateFieldsBeforeCLAOCompletion(appId);
                            System.debug('missingFields: ' + missingFields);
                            if(missingFields == null || String.isEmpty(missingFields))
                                apprecord.genesis__Status__c= 'CLAO FINAL APPROVAL';
                            else
                                return missingFields;
                            
                        } 
                else if(offer.Pricing_Detail__r.genesis__Application__r.genesis__Status__c == 'CLAO INITIAL APPROVAL'){
                    String missingFields = CLS_FieldValidation.ValidateFieldsBeforeCLAOCompletion(appId);
                    System.debug('missingFields: ' + missingFields);
                            if(missingFields == null || String.isEmpty(missingFields))
                                apprecord.genesis__Status__c= 'CLAO FINAL APPROVAL';
                            else
                                return missingFields;
                }
            }
            SecureDML.updateRecords(apprecord);            
            if(apprecord.genesis__Status__c == 'CLAO INITIAL APPROVAL')
                return 'CLAO Initial Approved';

            else if(apprecord.genesis__Status__c == 'CLAO FINAL APPROVAL'){
                return 'CLAO Final Approved';
            }   
            
            return 'Approval Invoke Action Failed';            
        }        
        catch(Exception e){
            system.debug('Error: ' + e.getMessage());
            return e.getMessage();
        }
    }  
    
    webservice static void UpdateApprovalReviewerModel(Id reviewerId, String reviewercomments ){
        clcommon__Reviewer__c reviewermodel = new clcommon__Reviewer__c(Id=reviewerId);
        reviewermodel.clcommon__Status__c = 'Approved';
        reviewermodel.clcommon__Review_Comments__c = reviewercomments;
        SecureDML.updateRecords(reviewermodel);
    }
}