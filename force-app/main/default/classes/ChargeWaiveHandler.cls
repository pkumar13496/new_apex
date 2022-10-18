global class ChargeWaiveHandler implements clcommon.PortalCustomRemoteAPI1{

    public clcommon.Response invokeAction(String componentStrName, String[] disclosureNames, Map<String,Object> values){
        clcommon.Response res = new clcommon.Response();
        List<Object> data = new List<Object>();
        Map < String, Object > fields = new Map < String, Object > {};
        List < clcommon.PortalCustomRemoteActionRecord > records    = new List < clcommon.PortalCustomRemoteActionRecord > {};
        ID contractId = (ID)values.get('contractId');
        String contractName = (String)values.get('contractName');
        String feeNames = (String)values.get('loanFeeId');
        Decimal  feeAmount = values.get('waiverAmount') != null ? Decimal.valueOf(String.valueOf(values.get('waiverAmount'))) : 0;
        Decimal sumOfTotalFees = 0;
        Set<Id> selectedIdSet = new Set<Id>((List<Id>) System.JSON.deserialize(String.valueOf(feeNames), List<Id>.class));
        List<AggregateResult> AggregateResultList = [select SUM(loan__Principal_Due__c) amt,loan__Loan_Account__c FROM loan__Charge__c 
            WHERE loan__Loan_Account__r.Name= :contractName  
            AND loan__Fee__c IN :selectedIdSet
            AND loan__Principal_Due__c > 0  group by loan__Loan_Account__c];
            if(AggregateResultList != null && AggregateResultList.size() > 0){  
            for(AggregateResult aggr:AggregateResultList){      
                sumOfTotalFees = (decimal)aggr.get('amt');        
            } 
            }
        if (!(Boolean)values.get('partialWaiver')){
            feeAmount = sumOfTotalFees; 
        }
            
        if (feeAmount > 0 &&  feeAmount > sumOfTotalFees) {
            res.errorMessage  = 'Sum of charges present on account for selected fees is less than waiver amount provided !! ';
            res.status = 'ERROR';
            return res;  
        } else if(feeAmount == 0 ){
            res.errorMessage  = 'Provied Waiver amount is 0 / there is no charge on account to Waive !!';
            res.status = 'ERROR';
            return res;
        } 
        List<Charge_Waiver_Request__c> waiverRequestList = [SELECT ID,Name,Status__c 
                                                    FROM Charge_Waiver_Request__c
                                                    WHERE CL_Contract__r.Name = :contractName 
                                                    AND Status__c = :CollectionsConstants.Submitted ];
        if (waiverRequestList != null && waiverRequestList.size()>0 ) {
            fields.put('page', 'Submited');
            fields.put('Message', 'There is pending request waiting for manager approval request number :  '+waiverRequestList[0].Name );
            clcommon.PortalCustomRemoteActionRecord record = new clcommon.PortalCustomRemoteActionRecord(null, fields);
            records.add(record);
            res = clcommon.PortalActions.getCustomRemoteActionResponse(records);
        } else {
            List<loan__Loan_Account__c> lAccList = [SELECT Id FROM loan__Loan_Account__c WHERE Name = :contractName ];
            if(lAccList != null && lAccList.size()>0){
            list<loan__Charge__c> chargelist =  [select loan__Fee__c,loan__Fee__r.name,loan__Loan_Account__c FROM loan__Charge__c 
            WHERE loan__Loan_Account__r.Name= :contractName  
            AND loan__Fee__c IN :selectedIdSet ];
            Charge_Waiver_Request__c waiverRequest = new Charge_Waiver_Request__c(CL_Contract__c = lAccList[0].Id, 
                                                            Charges_To_Be_Waived__c = feeNames,
                                                            Waive_Amount__c = feeAmount,
                                                            Fee_Name__c = chargelist[0].loan__Fee__r.name,
                                                            Status__c = CollectionsConstants.Submitted);
            SecureDML.insertRecords(waiverRequest);
            waiverRequestList = [SELECT ID,Name,Status__c,Waive_Amount__c 
                                                    FROM Charge_Waiver_Request__c
                                                    WHERE (CL_Contract__r.Name = :contractName 
                                                    AND Status__c = :CollectionsConstants.Submitted)
                                                    OR Id = :waiverRequest.Id ];
            fields.put('page', 'Submited');
            if(waiverRequestList != null && waiverRequestList.size()>0 && waiverRequestList[0].Status__c.equalsIgnoreCase(CollectionsConstants.Submitted)){
                fields.put('Message', 'Your request :   '+waiverRequestList[0].Name + '    is submitted for approval. ');
            } else {
                fields.put('Message', 'Your request :   '+waiverRequestList[0].Name + '    is processed and Fee Amount $'+waiverRequestList[0].Waive_Amount__c+' is waived');
            }
            clcommon.PortalCustomRemoteActionRecord record = new clcommon.PortalCustomRemoteActionRecord(null, fields);
            records.add(record);
            } else {
                fields.put('Message', 'Loan account not found !!');
                clcommon.PortalCustomRemoteActionRecord record = new clcommon.PortalCustomRemoteActionRecord(null, fields);
                records.add(record); 
            }
            res = clcommon.PortalActions.getCustomRemoteActionResponse(records);
        }
         return res;
    }
    @InvocableMethod(label='ProcessChargeWaiver')
    public static void ProcessChargeWaiver(List<ID> waiverRequest) {
        try { 
        
            list<Charge_Waiver_Request__c> chargeWaiverRequest = [select id, Charges_To_Be_Waived__c,
                                                                    CL_Contract__c,Waive_Amount__c,Status__c  
                                                                    FROM Charge_Waiver_Request__c 
                                                                    WHERE Id IN :waiverRequest ];
            Set<Id> selectedIdSet = new Set<Id>((List<Id>) System.JSON.deserialize(String.valueOf(chargeWaiverRequest[0].Charges_To_Be_Waived__c), List<Id>.class));
            List<loan__fee__c> feeList = [SELECT Id,Name FROM loan__fee__c 
                                            WHERE Id =: selectedIdSet ];
            List<String> feeNames = new List<String>();
                for (loan__fee__c fee : feeList) {
                    feeNames.add(fee.Name);
                } 
            loan.LoanActionFactory actionFactory = new loan.LoanActionFactory();
            actionFactory.getLoanAction12API().waiveCharge(chargeWaiverRequest[0].CL_Contract__c, feeNames, chargeWaiverRequest[0].Waive_Amount__c);
            chargeWaiverRequest[0].Status__c = CollectionsConstants.Processed; 
            SecureDML.updateRecords(chargeWaiverRequest);
        } catch (Exception ex) {
            throw ex;
        }
    } 
}