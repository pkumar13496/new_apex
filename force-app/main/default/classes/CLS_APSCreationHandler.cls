/**
 * CLS_APSCreationHandler.cls
 * @description Handler for APS Aura component
 * @author Asif Bhat, Q2 
 * @date  2021-May-12

 History
 *  2021-June-07 | | Asif Bhat | Removed commented out code, fixed alingments
 *  2021-July-27 | FUS-6282 | Asif Bhat | Removed leadtime check for all payment modes
 *  2021-August-31 | FUS-6560 | Asif Bhat | Removed the payment mode check for leadtime on Pre-Authorized Credit
 */
global class CLS_APSCreationHandler{
    
    @AuraEnabled public Date nextDueDate {get; set;}
    @AuraEnabled public Date endDate {get; set;}
    
    @AuraEnabled
    webservice static String validateBankAccount(Id bankId, Id loanId){
        loan__bank_Account__c bank = [SELECT id,name, 
                                             loan__Account__r.id,
                                             loan__active__c,
                                             Bank_Account_Status__c,
                                             loan__Account_Type__c 
                                     FROM loan__bank_account__c 
                                     WHERE id =: bankId ];

        loan__loan_account__c loan = [SELECT id,name,
                                             loan__Account__r.id,
                                             loan__loan_status__c 
                                     FROM loan__loan_account__c 
                                     WHERE id =: loanId ];
        
        
        List<clcommon__Party__c> parties = [SELECT id,name,
                                      			clcommon__Account__c
                                      FROM clcommon__Party__c 
                                      WHERE CL_Contract__r.id =: loanId ];
        
        Set<Id> partyAccountIds = new Set<Id>();
        for(clcommon__Party__c party : parties){
            partyAccountIds.add(party.clcommon__Account__c);
        }
        if(!'Active'.equalsIgnoreCase(bank.Bank_Account_Status__c)){
            return 'Bank Account is Inactive, please select an active bank account';
        }
        
        if(bank != null && loan != null){
            if(partyAccountIds.contains(bank.loan__Account__r.id)){
                return 'SUCCESS';
            }else{
                return 'Please select bank account related to parties of this contract';
            }
        }
        return 'Please select bank account related to parties of this contract';
    }
    
    @AuraEnabled
    webservice static String populatePaymentMode(Id bankId){
        String paymentMode;
        loan__bank_Account__c bank = [SELECT id,name,
                                             loan__Account__r.id,
                                             loan__Account_Type__c 
                                     FROM loan__bank_account__c 
                                     WHERE id =: bankId ];
        Map<String,String> paymentModeMap = new Map<String,String>();
        List<loan__payment_mode__c> paymentModes = [SELECT id,name 
                                                    FROM loan__payment_mode__c 
                                                    WHERE name in ('Pre-Authorized Credit','Pre-Authorized Visa Debit') ];
        for(loan__payment_mode__c pm : paymentModes){
            paymentModeMap.put(pm.Name,pm.id);
        }
        if('PAD'.equalsIgnoreCase(bank.loan__Account_Type__c)){
            paymentMode = paymentModeMap.get('Pre-Authorized Credit');
            if(paymentMode == null){
                loan__payment_mode__c newMode = new loan__payment_mode__c();
                newMode.name = 'Pre-Authorized Credit';
                SecureDML.insertRecords(newMode);
                List<loan__payment_mode__c> newModes = [SELECT id,name 
                                                        FROM loan__payment_mode__c 
                                                        WHERE name = 'Pre-Authorized Credit'];
                paymentMode = paymentModes[0].id;
            }
       }else if('Visa/Debit'.equalsIgnoreCase(bank.loan__Account_Type__c)){
           paymentMode = paymentModeMap.get('Pre-Authorized Visa Debit');
           if(paymentMode == null){
               loan__payment_mode__c newMode = new loan__payment_mode__c();
               newMode.name = 'Pre-Authorized Visa Debit';
               SecureDML.insertRecords(newMode);
               List<loan__payment_mode__c> newModes = [SELECT id,name 
                                                      FROM loan__payment_mode__c 
                                                      WHERE name ='Pre-Authorized Visa Debit'];
                paymentMode = paymentModes[0].id;
           }
        }
       return paymentMode; 
    }
    
    @AuraEnabled
    webservice static CLS_APSCreationHandler populateDates(Id loanId){
        loan__loan_account__c loan = [SELECT id,name,
                                             loan__Next_Installment_Date__c,
                                             loan__Maturity_Date_Current__c,
                                              loan__Last_Installment_Date__c 
                                     FROM loan__loan_account__c 
                                     WHERE id =: loanId ];
        
        CLS_APSCreationHandler obj = new CLS_APSCreationHandler();
        obj.nextDueDate = loan.loan__Next_Installment_Date__c;
        obj.endDate = loan.loan__Maturity_Date_Current__c;
        Date currentSystemDate = new loan.GlobalLoanUtilFacade().getCurrentSystemDate();
        Integer days = Math.ABS(obj.nextDueDate.daysBetween(currentSystemDate));
        if(days <= 2){
            loan__Repayment_Schedule__c rsa = [SELECT id,name,
                                                        loan__Due_Date__c 
                                                 FROM loan__Repayment_Schedule__c 
                                                 WHERE loan__Loan_Account__r.id =: loanId 
                                                 AND loan__Due_Date__c > :obj.nextDueDate 
                                                 ORDER BY loan__Due_Date__c ASC limit 1];
            obj.nextDueDate = rsa.loan__Due_Date__c;   
        }
        return obj;
        
    }
    
    @AuraEnabled
    webservice static String checkLeadTime(Date debitDate, String paymentModeId){
        /*if(paymentModeId == null){
            return 'Payment Mode Cannot be null';
        }*/
       Date currentSystemDate = new loan.GlobalLoanUtilFacade().getCurrentSystemDate();
       Integer days = Math.ABS(currentSystemDate.daysBetween(debitDate));
      /* loan__payment_mode__c paymentMode = [SELECT id,name 
                                            FROM loan__payment_mode__c 
                                            WHERE id =: paymentModeId];*/
        Integer numberDaysDue = currentSystemDate.daysBetween(debitDate);
        system.debug('numberDaysDue is '+numberDaysDue);
        System.debug('LeadTime: '+days);
        //if(!String.isBlank(paymentModeId)){
        if(numberDaysDue < 0){
            return 'Debit date can not be backdated.';
        }
       		if(days <= 2){
           		return 'Insufficient Lead Time, Please select another date';
       		}
    	//}
        return 'Success';
       	
    }
    
    @AuraEnabled
    webservice static String validateTxnAmount(Id loanId, Decimal transactionAmount){
        if(transactionAmount == null){
            return 'Transaction Amount cannot be null';
        } 
       loan__loan_account__c la = [SELECT id,name,
                                          Total_Current_payment_Amount_new__c 
                                  FROM loan__loan_account__c 
                                  WHERE id =: loanId ];
       if(transactionAmount != la.Total_Current_payment_Amount_new__c){
           return 'Transaction amount must be equal to Current Payment Amount.';
       }else{
           return 'Success';
       }
    }
    @AuraEnabled
    webservice static String validateAPS(Id loanId){
        loan__loan_account__c la = [SELECT id,name, 
                                            loan__loan_status__c 
                                    FROM loan__loan_account__c 
                                    WHERE id =: loanId ];
       if(!'Active - Good Standing'.equalsIgnoreCase(la.loan__loan_status__c) && !'Active - Bad Standing'.equalsIgnoreCase(la.loan__loan_status__c)){
           return 'Invalid loan status to set up APS';
       }else{
           return 'Success';
       }
    }    
    
}