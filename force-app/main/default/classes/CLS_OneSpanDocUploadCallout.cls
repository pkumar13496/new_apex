/**
 * Author : Prithvi
 */
global class CLS_OneSpanDocUploadCallout {
    static final String APPLICATION_DOCUMENTS = 'Application Documents';
    static final String LOAN_DOCUMENTS = 'Loan Documents';
    static final String COLLECTION_DOCUMENTS = 'Collection Documents';
    static final String INVALID_PARAMS = 'Please pass required parameters.';
    static final String INVALID_ASSOCIATION_ERR_MSG = 'Association should belong to either Party/Application/Loan/Colleciton Documents: ';
    static final String INVALID_FOLDERS = 'Cannot proceed with Signing ceremony, invalid document folders';
    static final String SUCCESS_RESPONSE_MESSAGE = 'Signing ceremony initiated';
    static final String FAILURE_RESPONSE_MESSAGE = 'Something went wrong.';
    static final string ESIGN_VALIDATION = 'Esign Validation';
    static final string CLOSED_OBLIGATION_MET = 'Closed - Obligations met';
	static final string ERROR_MESSAGE = 'You don\'t have sufficient permission to perform this action';
    
    webservice static String evaluateEsign(Id applicationId) {
        //Full Applications for Unsecured New Loans 
        //where the customer had a previous Unsecured Core Loans
        
        //List<genesis__Applications__c> appList = [select id,Application_Type__c,AssetClass__c,genesis__Account__c 
        //from genesis__Applications__c where id =:applicationId];
        //full unsecured .. //only new dont check refinence and increase ... point 3 covers increase..
        List<clcommon__Party__c> clPartyApplicants = [select Id, Party_Type_Text__c ,Party_type_for_esign__c,clcommon__Contact__r.email ,
                                                      genesis__Application__r.genesis__Account__c,genesis__Application__r.Application_Type__c , 
                                                      genesis__Application__r.Loan_Type__c, genesis__Application__r.Asset_type__c,
                                                      genesis__Application__r.Selected_Offer_Type__c, genesis__Application__r.ownerid,
                                                      genesis__Application__r.Branch__c,genesis__Application__r.AssetClass__c,
                                                      genesis__Application__r.Special_Loan_Type__c 
                                                      from clcommon__Party__c 
                                                      where genesis__Application__c = :applicationId  
                                                      and (Party_Type_Text__c = 'borrower' or Party_Type_Text__c = 'co-borrower')];
        
        system.debug('clPartyApplicants**'+clPartyApplicants);
        
        Id Accountid ;
        string borrowerEmail;
        string coBorrowerEmail;
        String applicationType;
        String loanType;
        string offerType;
        String ownerid;
        String branchName;
        if(clPartyApplicants!=null){
            for(clcommon__Party__c clp :  clPartyApplicants){
                system.debug('clp**'+clp);
                Accountid = clp.genesis__Application__r.genesis__Account__c;
                applicationType = clp.genesis__Application__r.Application_Type__c; //Full or Express
                loanType = clp.genesis__Application__r.Loan_Type__c; //New or Increase or refinance.
                offerType = clp.genesis__Application__r.AssetClass__c; //UPL/ SPL
                ownerid = clp.genesis__Application__r.ownerid;
                branchName = clp.genesis__Application__r.Branch__c;
                system.debug('genesis__Application__r.Special_Loan_Type__c**'+clp.genesis__Application__r.Special_Loan_Type__c);
                if(clp.Party_Type_Text__c == 'borrower'){
                    borrowerEmail = clp.clcommon__Contact__r.email;
                }
                else{
                    coBorrowerEmail = clp.clcommon__Contact__r.email;
                } 
            }
            System.debug('borrowerEmail**'+borrowerEmail+'##coBorrowerEmail###'+coBorrowerEmail);
            system.debug('applicationType**'+applicationType);
            system.debug('loanType**'+loanType);
            system.debug('offerType**'+offerType);
            system.debug('ownerid**'+ownerid);
            system.debug('branchName**'+branchName);
            if(offerType=='UPL'){
                //if borrower email and coborroweemail are same then thoow exception.
                if((borrowerEmail !=null && coBorrowerEmail != null) && (borrowerEmail == coBorrowerEmail)){
                    return ERROR_MESSAGE;
                }
                
                //check branch if subtype centralised 
                // branch subtype (field) --> centralised values. junction assocation --> user to branch
                //user owner branch,, application branch
                List<UserStoreRoleAssociation__c> userStoreRoleAssoList = [select id from UserStoreRoleAssociation__c 
                                                                           where Store__r.name =:branchName 
                                                                           and User__c  =:ownerid 
                                                                           and store__r.Sub_Type__c  = 'Centralized'];
                system.debug('userStoreRoleAssoList**'+userStoreRoleAssoList);
                //if not assocations available , then proceed for futher evaluation. else skipp error
                if(userStoreRoleAssoList.isEmpty() ){
                    
                    //if the label is null, do not evluate the rule condition
                    //also if "Full Applications for Unsecured New Loan"
                    if(System.Label.ESignLastNDays != null && applicationType == 'Full' && loanType == 'New' && offerType =='UPL'){
                        string esingLastDay = System.Label.ESignLastNDays;
                        esingLastDay = esingLastDay.trim();
                        Integer lastNDays = Integer.valueof(esingLastDay);
                        system.debug('lastNDays**'+lastNDays);
                        Date d = system.today();        
                        Date lastNday = d.addDays(-lastNDays); 
                        //Query on parties to --> where the customer had a previous "Unsecured Core Loans" that was "paid out"  within the last 60 day
                        List<clcommon__Party__c>  parties = [select id,CL_Contract__r.loan__Last_Payment_Date__c  from clcommon__Party__c  
                                                             where CL_Contract__r.loan__Last_Payment_Date__c >= :lastNDay  and 
                                                             CL_Contract__r.loan__Loan_Status__c =:CLOSED_OBLIGATION_MET  and 
                                                             genesis__Application__r.genesis__Account__c =:Accountid and 
                                                             CL_Contract__r.loan__Loan_Product_Name__r.Name = 'Unsecured Personal Loan'];
                        
                        system.debug('parties**'+parties);
                        if(parties.size()==0){
                            return ERROR_MESSAGE;
                        }
                    }
                    
                    List<clcommon__Rule__c> clCommonRulesList =  [SELECT Id, Name,
                                                                  clcommon__Enabled__c,
                                                                  clcommon__Object_Type__c,
                                                                  clcommon__Parent_Rule__c,
                                                                  clcommon__Rule_Json__c,
                                                                  clcommon__Rule_Priority__c,
                                                                  clcommon__Rule_Set__c
                                                                  FROM clcommon__Rule__c
                                                                  WHERE Name =: ESIGN_VALIDATION
                                                                  AND clcommon__Enabled__c = true];
                    
                    clcommon.RulesAPI2 rulesIns = clcommon.APIFactory.getRulesAPI2();
                    rulesIns.setIDs(new set<Id> {applicationId});
                    rulesIns.setRules(clCommonRulesList);
                    rulesIns.evaluate();
                    
                    Map<String,Set<Id>> failedRecords =  rulesIns.getFailureRecIds();
                    
                    system.debug('failedRecords.size()=='+failedRecords.size());
                    system.debug('failedRecords.keySet()=='+failedRecords.keySet());
                    // throwing exception incase of any failed rules associated.
                    if(failedRecords.size() > 0) {
                        system.debug('Evaluation criteria with Following rule association with Status Change failed '+ failedRecords.keySet());
                        if(!failedRecords.isEmpty() && failedRecords.containsKey(ESIGN_VALIDATION)){
                            if(failedRecords.get(ESIGN_VALIDATION).contains(applicationId)){
                                return ERROR_MESSAGE;
                            }
                        }                    
                    }
                }
            }
        }
        return null;
    }
    webservice static String postDocAPI(List<Id> categoryAssociationIds, Id applicationId) {
        try{      
            if(categoryAssociationIds == null || categoryAssociationIds.isEmpty() || String.isBlank(applicationId)) {
                return INVALID_PARAMS;
            }

            //Segregate attachments based on doc-folder
            Map<String,List<Id>> folderToAttachmentIdMap = new Map<String,List<Id>>();
            Map<String,List<Id>> folderToAssociationIdMap = new Map<String,List<Id>>();
            Map<Id,Id> attXasc = new Map<Id,Id>();
            Map<String,clcommon__Document_Category__c> keyXSignsMap = new Map<String,clcommon__Document_Category__c>();

            for(clcommon__Category_Attachment_Association__c association : [SELECT Id, clcommon__Document_Category__r.clcommon__Account__c, clcommon__Document_Category__r.clcommon__Category_Name__c, clcommon__Document_Category__r.clcommon__Parent_Document_Category__r.clcommon__Category_Name__c, 
                                                        clcommon__Document_Category__r.Borrower_Signs__c, clcommon__Document_Category__r.CoBorrower_Signs__c, clcommon__Document_Category__r.CoSigner_Signs__c, clcommon__Document_Category__r.Initials__c, clcommon__Document_Category__r.Employee_Signs__c, clcommon__Document_Category__r.CLL_CLC_FSR_Signature__c, clcommon__Attachment_Id__c FROM clcommon__Category_Attachment_Association__c WHERE Id IN : categoryAssociationIds AND clcommon__Attachment_Id__c != null AND 
                                                        clcommon__Document_Category__r.clcommon__Parent_Document_Category__r.clcommon__Category_Name__c != null ]) {
                String checkKey;
                attXasc.put(association.clcommon__Attachment_Id__c, association.Id);
                if(association.clcommon__Document_Category__r.clcommon__Parent_Document_Category__r.clcommon__Category_Name__c == APPLICATION_DOCUMENTS) {
                    checkKey = APPLICATION_DOCUMENTS;
                }else if(association.clcommon__Document_Category__r.clcommon__Account__c != null) {
                    checkKey = association.clcommon__Document_Category__r.clcommon__Account__c;
                }else {
                    throw new OneSpanCalloutException(INVALID_ASSOCIATION_ERR_MSG+ association.Id);
                }
                System.debug('--- checkKey'+checkKey);
                if(folderToAttachmentIdMap.containsKey(checkKey)) {
                    folderToAttachmentIdMap.get(checkKey).add(association.clcommon__Attachment_Id__c);
                    folderToAssociationIdMap.get(checkKey).add(association.Id);

                }else {
                    folderToAttachmentIdMap.put(checkKey, new List<Id>{association.clcommon__Attachment_Id__c});
                    folderToAssociationIdMap.put(checkKey, new List<Id>{association.Id});
                }

                //no of signs
                keyXSignsMap.put(checkKey, association.clcommon__Document_Category__r);
                
            }
            System.debug('--- keyXSignsMap'+keyXSignsMap);
            Map<Id,List<Id>> accountXcontact = new Map<Id,List<Id>>();
            Map<Id,clcommon__Party__c> contactXanchor = new Map<Id,clcommon__Party__c>();
            for(clcommon__Party__c party : [SELECT id, clcommon__Type__r.name, Party_type_for_esign__c, clcommon__Contact__c, clcommon__Account__c,
                                                  genesis__Application__r.Need_Re_Submit__c, OneSpan_Sign_Anchor__c, OneSpan_Initial_Anchor__c FROM clcommon__Party__c
                                                  WHERE genesis__Application__c =:applicationId AND clcommon__Contact__c != null AND clcommon__Account__c != null AND
                                                  (clcommon__Type__r.name = :CLS_GDS_Constants.CLO_BORROWER_PARTY_TYPE OR clcommon__Type__r.name = :CLS_GDS_Constants.CLO_CO_BORROWER_PARTY_TYPE OR clcommon__Type__r.name = :CLS_GDS_Constants.CLO_CO_SIGNER_PARTY_TYPE) ]) 
            {
                
                contactXanchor.put(party.clcommon__Contact__c, party);
                accountXcontact.put(party.clcommon__Account__c, new List<Id>{party.clcommon__Contact__c});
                
            }

            if(folderToAttachmentIdMap.isEmpty() || contactXanchor.isEmpty()) {
                return INVALID_FOLDERS;
            }
            System.debug('--- accountXcontact '+accountXcontact);
            System.debug('--- folderToAttachmentIdMap '+folderToAttachmentIdMap);
            Map<String,Object> requestParamMap = new Map<String,Object>{'contactXanchor' => contactXanchor, 'applicationId' => applicationId, 'attXasc' => attXasc};
            Map<String,Object> queryIdMap;

            //Initiate async signing per folder
            for(String folder : folderToAttachmentIdMap.keySet()) {
                System.debug('--- folder '+folder);
                if(folder == APPLICATION_DOCUMENTS) {
                    queryIdMap = new Map<String,Object>{'attachmentIds' => folderToAttachmentIdMap.get(folder), 'contactIds' => new List<Id>(contactXanchor.keySet())};
                    requestParamMap.put('attAssociationIds', folderToAssociationIdMap.get(folder));
                    requestParamMap.put('signature_details', keyXSignsMap.get(folder));
                    intframework.AbstractIntegrationService baseintegrationService = intframework.IntegrationServiceFactory.getBaseIntegrationService();
                    intframework.BaseIntegrationResponse responseObject = (intframework.BaseIntegrationResponse)baseintegrationService.runSynchronousIntegrationService('OneSpan','OneSpan',1,queryIdMap,requestParamMap);
                    System.debug('---' + responseObject);    
                }else if(accountXcontact.containsKey(folder)) {
                    queryIdMap = new Map<String,Object>{'attachmentIds' => folderToAttachmentIdMap.get(folder), 'contactIds' => accountXcontact.get(folder)};
                    requestParamMap.put('attAssociationIds', folderToAssociationIdMap.get(folder));
                    requestParamMap.put('signature_details', keyXSignsMap.get(folder));
                    intframework.AbstractIntegrationService baseintegrationService = intframework.IntegrationServiceFactory.getBaseIntegrationService();
                    intframework.BaseIntegrationResponse responseObject = (intframework.BaseIntegrationResponse)baseintegrationService.runSynchronousIntegrationService('OneSpan','OneSpan',1,queryIdMap,requestParamMap);
                    System.debug('---' + responseObject);    
                }
                        

            }
            
            return SUCCESS_RESPONSE_MESSAGE;               
        }catch(Exception e){
            System.debug('--- error msg ' + e.getMessage());
            System.debug('--- line no ' + e.getLineNumber());  
        }
        return FAILURE_RESPONSE_MESSAGE;
    }

    /**
     * Description : To process loan and collection documents.
     */
    webservice static String postLoanDocs(List<Id> categoryAssociationIds, Id contractId, Boolean isLoan) {
        try {
            if(categoryAssociationIds == null || categoryAssociationIds.isEmpty() || String.isBlank(contractId)) {
                return INVALID_PARAMS;
            }
            String commonCategoryName;
            if(isLoan)
                commonCategoryName = LOAN_DOCUMENTS;
            else
                commonCategoryName = COLLECTION_DOCUMENTS;

            //Segregate attachments based on doc-folder
            Map<String,List<Id>> folderToAttachmentIdMap = new Map<String,List<Id>>();
            Map<String,List<Id>> folderToAssociationIdMap = new Map<String,List<Id>>();
            Map<Id,Id> attXasc = new Map<Id,Id>();
            Map<String,clcommon__Document_Category__c> keyXSignsMap = new Map<String,clcommon__Document_Category__c>();

            for(clcommon__Category_Attachment_Association__c association : [SELECT Id, clcommon__Document_Category__r.clcommon__Account__c,
                                                                            clcommon__Document_Category__r.clcommon__Parent_Document_Category__r.clcommon__Category_Name__c, clcommon__Document_Category__r.clcommon__Category_Name__c,
                                                                            clcommon__Document_Category__r.Borrower_Signs__c, clcommon__Document_Category__r.CoBorrower_Signs__c, clcommon__Document_Category__r.CoSigner_Signs__c, clcommon__Document_Category__r.Initials__c, clcommon__Document_Category__r.Employee_Signs__c, clcommon__Document_Category__r.CLL_CLC_FSR_Signature__c, clcommon__Attachment_Id__c 
                                                                            FROM clcommon__Category_Attachment_Association__c WHERE Id IN : categoryAssociationIds AND clcommon__Attachment_Id__c != null 
                                                                            AND clcommon__Document_Category__r.clcommon__Parent_Document_Category__r.clcommon__Category_Name__c != null ]) {
                String checkKey;
                attXasc.put(association.clcommon__Attachment_Id__c, association.Id);
                if(association.clcommon__Document_Category__r.clcommon__Parent_Document_Category__r.clcommon__Category_Name__c == commonCategoryName) {
                    checkKey = commonCategoryName;
                }else if(association.clcommon__Document_Category__r.clcommon__Account__c != null) {
                    checkKey = association.clcommon__Document_Category__r.clcommon__Account__c;
                }else {
                    throw new OneSpanCalloutException(INVALID_ASSOCIATION_ERR_MSG+ association.Id);
                }
                System.debug('--- checkKey'+checkKey);
                if(folderToAttachmentIdMap.containsKey(checkKey)) {
                    folderToAttachmentIdMap.get(checkKey).add(association.clcommon__Attachment_Id__c);
                    folderToAssociationIdMap.get(checkKey).add(association.Id);

                }else {
                    folderToAttachmentIdMap.put(checkKey, new List<Id>{association.clcommon__Attachment_Id__c});
                    folderToAssociationIdMap.put(checkKey, new List<Id>{association.Id});
                }

                //no of signs
                keyXSignsMap.put(checkKey, association.clcommon__Document_Category__r);
                
            }

            Map<Id,List<Id>> accountXcontact = new Map<Id,List<Id>>();
            Map<Id,clcommon__Party__c> contactXanchor = new Map<Id,clcommon__Party__c>();
            for(clcommon__Party__c party : [SELECT id, clcommon__Type__r.name, Party_type_for_esign__c, clcommon__Contact__c, clcommon__Account__c, OneSpan_Sign_Anchor__c, OneSpan_Initial_Anchor__c FROM clcommon__Party__c
                                                    WHERE CL_Contract__c =:contractId AND clcommon__Contact__c != null AND clcommon__Account__c != null AND
                                                    (clcommon__Type__r.name = :CLS_GDS_Constants.CLO_BORROWER_PARTY_TYPE OR clcommon__Type__r.name = :CLS_GDS_Constants.CLO_CO_BORROWER_PARTY_TYPE) ]) 
            {
                
                contactXanchor.put(party.clcommon__Contact__c, party);
                accountXcontact.put(party.clcommon__Account__c, new List<Id>{party.clcommon__Contact__c});
                    
            }

            if(folderToAttachmentIdMap.isEmpty() || contactXanchor.isEmpty()) {
                return INVALID_FOLDERS;
            }
            System.debug('--- accountXcontact '+accountXcontact);
            System.debug('--- folderToAttachmentIdMap '+folderToAttachmentIdMap);
            Map<String,Object> requestParamMap = new Map<String,Object>{'contactXanchor' => contactXanchor, 'applicationId' => contractId, 'attXasc' => attXasc};
            Map<String,Object> queryIdMap;

            //Initiate async signing per folder
            for(String folder : folderToAttachmentIdMap.keySet()) {
                System.debug('--- folder '+folder);
                if(folder == LOAN_DOCUMENTS || folder == COLLECTION_DOCUMENTS) {
                    queryIdMap = new Map<String,Object>{'attachmentIds' => folderToAttachmentIdMap.get(folder), 'contactIds' => new List<Id>(contactXanchor.keySet())};
                    requestParamMap.put('attAssociationIds', folderToAssociationIdMap.get(folder));
                    requestParamMap.put('signature_details', keyXSignsMap.get(folder));
                    intframework.AbstractIntegrationService baseintegrationService = intframework.IntegrationServiceFactory.getBaseIntegrationService();
                    intframework.BaseIntegrationResponse responseObject = (intframework.BaseIntegrationResponse)baseintegrationService.runSynchronousIntegrationService('OneSpan','OneSpan',1,queryIdMap,requestParamMap);
                    System.debug('---' + responseObject);    
                }else if(accountXcontact.containsKey(folder)) {
                    queryIdMap = new Map<String,Object>{'attachmentIds' => folderToAttachmentIdMap.get(folder), 'contactIds' => accountXcontact.get(folder)};
                    requestParamMap.put('attAssociationIds', folderToAssociationIdMap.get(folder));
                    requestParamMap.put('signature_details', keyXSignsMap.get(folder));
                    intframework.AbstractIntegrationService baseintegrationService = intframework.IntegrationServiceFactory.getBaseIntegrationService();
                    intframework.BaseIntegrationResponse responseObject = (intframework.BaseIntegrationResponse)baseintegrationService.runSynchronousIntegrationService('OneSpan','OneSpan',1,queryIdMap,requestParamMap);
                    System.debug('---' + responseObject);    
                }
                        

            }
            return SUCCESS_RESPONSE_MESSAGE;  
        }catch(Exception e){
            System.debug('--- error msg ' + e.getMessage());
            System.debug('--- line no ' + e.getLineNumber());  
        }
        return FAILURE_RESPONSE_MESSAGE;
        
    }


    public class OneSpanCalloutException extends Exception {}
}