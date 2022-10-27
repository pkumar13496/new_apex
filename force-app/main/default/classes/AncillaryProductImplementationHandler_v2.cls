global class AncillaryProductImplementationHandler_v2 {
    public class AncillaryProductException extends Exception {}
    static boolean LPP_prepaid = false;
    static boolean LPP = false;
    static boolean hna = false;
    static boolean creditOpt = false;
    static CLS_Selected_Ancillary_Product__c creditOptimizerSubscribed = new CLS_Selected_Ancillary_Product__c();
    static CLS_Selected_Ancillary_Product__c hnaSubscribed = new CLS_Selected_Ancillary_Product__c();
    static CLS_Selected_Ancillary_Product__c lppSubscribed = new CLS_Selected_Ancillary_Product__c();

    @InvocableMethod
    public static void processAncillaryProduct(List < ID > contractIds) {

        List < loan__loan_account__c > loanAccList = [Select id, name,
                                                             RecordTypeId,
                                                             loan__Periodic_Fee__c,
                                                             loan__Maturity_Date_Current__c,
                                                             Contra_Loan_Account__r.id, 
                                                             loan__Last_Installment_Date__c, 
                                                             loan__First_Installment_Date__c, 
                                                             loan__Account__r.id, loan__Loan_Status__c,
                                                             Lending_Product_Name__c,
                                                             loan__Expected_Repayment_Start_Date__c,
                                                             Contra_Loan_Account__r.loan__Loan_Status__c, 
                                                             loan__Loan_Purpose__r.id, 
                                                             loan__Disbursal_Status__c, 
                                                             loan__Branch__r.id, 
                                                             Contra_Loan_Account__r.Name,
                                                             loan__Next_Installment_Date__c,
                                                             loan__Second_Installment_Date__c,
                                                             application__c, 
                                                             loan__Frequency_of_Loan_Payment__c,
                                                             (SELECT id,name,
                                                                    Account__c, 
                                                                    Application__c,
                                                                    Is_Active__c,
                                                                    Is_Pre_Paid__c,
                                                                    Type__c,
                                                                    Subscription_Fees__c  
                                                             FROM CLS_Selected_Ancillary_Products__r 
                                                             WHERE ( type__c=: 'Protection Plan' OR type__c =: 'Credit Optimizer' OR type__c =: 'Insurance' )) 
                                                    FROM loan__loan_account__c where id in: contractIds ];
        
       // processCreditOptimizer(contractIds);
       // processHomeAndAuto(contractIds);
       List<Id> closedLoanIds = new List<Id>();
       List<Id> activeLoanIds = new List<Id>();
       for (loan__loan_account__c loanAcc: loanAccList) {
          if ('Closed - Obligations met'.equalsIgnoreCase(loanAcc.loan__Loan_Status__c) || 'Closed- Written Off'.equalsIgnoreCase(loanAcc.loan__Loan_Status__c)) {
            closedLoanIds.add(loanAcc.id);
           }else{
            activeLoanIds.add(loanAcc.id);
           } 
        }
        //if(!System.isBatch()){
        if(closedLoanIds.size() > 0){
          
            deActivateAncillariesOnMainLoan(closedLoanIds);
            activateAncillariesOnContraLoan(closedLoanIds);
        }
        if(activeLoanIds.size() > 0){
           
            processLoanProtectionPlan(activeLoanIds); 
            processStandAloneAncillaries(activeLoanIds);
            }
        //}    
        //processCreditOptimizer(contractIds);
        //processHomeAndAuto(contractIds);
    }
    
    
    //Method to process LPP Product based on loan__loan_account__c fields..
    //@future
    public static void processLoanProtectionPlan(List<String> loanAccIds) {
        List<loan__loan_Account__c> loanAccs = getLoanAccounts(loanAccIds);
        Map<Id,loan__Periodic_Fee_Setup__c> loanAccXPeriodicFeeMap = populateLoanLPPMap(loanAccIds);
        Map<Id,loan__Repayment_Schedule__c> loanIdXOffsetOneAmzSchedule = populateAmzScheduleMap(loanAccIds);
        List<loan__Periodic_Fee_Setup__c> toBeUpdatedPeriodicFees = new List<loan__Periodic_Fee_Setup__c>();
        for(loan__loan_Account__c loanAcc : loanAccs){
            List<CLS_Selected_Ancillary_Product__c> clsSelectedAnciProduct = loanAcc.CLS_Selected_Ancillary_Products__r;
            if(clsSelectedAnciProduct.size() > 0){
                for(CLS_Selected_Ancillary_Product__c clsSelectedProd : clsSelectedAnciProduct){
                    if(clsSelectedProd.type__c.equalsIgnoreCase('Protection Plan')){
                        if(LPP){
                            continue;
                        }
                        LPP = clsSelectedProd.is_active__c;
                        lppSubscribed = clsSelectedProd;
                        if(clsSelectedProd.Is_Pre_Paid__c){
                            LPP_prepaid = true;
                        }
                    }else if(clsSelectedProd.type__c.equalsIgnoreCase('Credit Optimizer')){
                        creditOpt = clsSelectedProd.is_active__c;
                        creditOptimizerSubscribed = clsSelectedProd;
                    }else if(clsSelectedProd.type__c.equalsIgnoreCase('Insurance')){
                        hna = clsSelectedProd.is_active__c;
                        hnaSubscribed = clsSelectedProd;
                    }

                }
            }  
            System.debug('lppSubscribed: '+lppSubscribed);
            if ((!String.isBlank(loanAcc.loan__Disbursal_Status__c) && (loanAcc.loan__Disbursal_Status__c.equals('Partially Disbursed') || loanAcc.loan__Disbursal_Status__c.equals('Fully Disbursed')))) {

                loan__Periodic_Fee_Setup__c periodicFeeSetup = loanAccXPeriodicFeeMap.get(loanAcc.Id);
                
                if (periodicFeeSetup != null && !loanAcc.Lending_Product_Name__c.contains('Ancillary Product')) {
                    if (LPP && LPP_prepaid == true) {
                        if (!periodicFeeSetup.loan__Active__c) {
                            //Activate LPP Prepaid, if not active already..
                            periodicFeeSetup.loan__Active__c = true;
                            periodicFeeSetup.loan__Next_Recurring_Fee_Date__c = loanAcc.loan__Next_Due_generation_Date__c;
                            periodicFeeSetup.Actual_Date__c= loanAcc.loan__Next_Installment_Date__c;
                            periodicFeeSetup.loan__Amount__c = lppSubscribed.Subscription_Fees__c;
                            //create a charge..loan__charge__c.. with amount on LPP Periodic Fee Setup..
                            insertChargeAndLPT(periodicFeeSetup.loan__Fee__r, loanAcc.id, periodicFeeSetup.loan__Amount__c, false, periodicFeeSetup.id);

                        } else if (loanAcc.loan__Maturity_Date_Current__c != loanAcc.loan__Last_Installment_Date__c) {
                            //Set Fee End Date on Periodic Fee Setup if Current Maturity Date is changed on contract..
                            if(loanIdXOffsetOneAmzSchedule.get(loanAcc.id) != null){
                                periodicFeeSetup.Fee_End_Date__c = loanIdXOffsetOneAmzSchedule.get(loanAcc.id).loan__Due_Date__c;
                            }
                        }

                    } else if (LPP == true) {
                        periodicFeeSetup.loan__Active__c = true;
                        periodicFeeSetup.loan__Amount__c = lppSubscribed.Subscription_Fees__c;

                    } else if (LPP == false) {
                        periodicFeeSetup.loan__Active__c = false;
                    }
                    toBeUpdatedPeriodicFees.add(periodicFeeSetup);
                } else {
                    throw new AncillaryProductException('No Periodic Fee Setup for LPP');
                }
            }
        }
        try {
            SecureDML.updateRecords(toBeUpdatedPeriodicFees);
        } catch (Exception e) {
            system.debug('Exception ---' + e);
        }
    }

   // @future
    public static void processStandAloneAncillaries(List<String> loanAccIds) { //If CO Active done on 'Ancillary Product' loan account..
        List<loan__loan_Account__c> loanAccs = getLoanAccounts(loanAccIds);
        
        loan__Payment_Mode__c paymentMode  = [SELECT id, name 
                                              FROM loan__Payment_Mode__c 
                                              WHERE Name like '%Cash%'  limit 1 ];
        
        Map<Id,List<loan__Periodic_Fee_Setup__c>> loanIdXStandAlonePeriodicFeeMap = populateLoanStandAloneAncillaryMap(loanAccIds);
        Map<Id,List<loan__loan_account__c>> accountIdXLoanAccount = populateAccountIdXNonAncillaryLoanMap(loanAccs);
        Map<Id, List<loan__Automated_Payment_Setup__c>> loanIdXAPSMap = populateLoanAPSMap(loanAccIds);
        Map<Id,List<loan__loan_account__c>> accountIdXContraLoanMap = populateAccountIdXContraLoanAccountMap(loanAccs);
        for(loan__loan_Account__c loanAcc : loanAccs){
            List<CLS_Selected_Ancillary_Product__c> clsSelectedAnciProduct = loanAcc.CLS_Selected_Ancillary_Products__r;
            if(clsSelectedAnciProduct.size() > 0){
                for(CLS_Selected_Ancillary_Product__c clsSelectedProd : clsSelectedAnciProduct){
                    if(clsSelectedProd.type__c.equalsIgnoreCase('Protection Plan')){
                        LPP = clsSelectedProd.is_active__c;
                        if(clsSelectedProd.Is_Pre_Paid__c){
                            LPP_prepaid = true;
                        }
                    }else if(clsSelectedProd.type__c.equalsIgnoreCase('Credit Optimizer')){
                        creditOpt = clsSelectedProd.is_active__c;
                        creditOptimizerSubscribed = clsSelectedProd;
                    }else if(clsSelectedProd.type__c.equalsIgnoreCase('Insurance')){
                        hna = clsSelectedProd.is_active__c;
                        hnaSubscribed = clsSelectedProd;
                    }

                }
            }
            List<loan__Periodic_Fee_Setup__c> periodicFeeSetups = loanIdXStandAlonePeriodicFeeMap.get(loanAcc.id);
            
            if (loanAcc.Lending_Product_Name__c.contains('Ancillary Product')) {
                if (hna == true && loanAcc.Contra_Loan_Account__c != null) {
                    throw new AncillaryProductException('Activate H&A on Primary Account: ' + loanAcc.Contra_Loan_Account__r.Name);
                } else if (LPP == true && loanAcc.Contra_Loan_Account__c != null) {
                    throw new AncillaryProductException('Activate LPP on Primary Account: ' + loanAcc.Contra_Loan_Account__r.Name);
                } else if (LPP == true && loanAcc.Contra_Loan_Account__c == null) {
                    throw new AncillaryProductException('LPP is not standalone Ancillary Product');
                } else if (creditOpt == true && loanAcc.Contra_Loan_Account__c != null) {
                    throw new AncillaryProductException('Activate CO on Primary Account: ' + loanAcc.Contra_Loan_Account__r.Name);
                } else if ((hna == true || creditOpt == true) && loanAcc.Contra_Loan_Account__c == null) {
                    loan__loan_account__c contaLoanAcc = null;
                    if (loanAcc.Contra_Loan_Account__c == null) {
                        List < loan__loan_account__c > contaLoanAccList = accountIdXLoanAccount.get(loanAcc.loan__Account__r.id);
                        if (contaLoanAccList.size() > 0) {
                            contaLoanAcc = contaLoanAccList.get(0);
                        }
                    }
                    if (contaLoanAcc == null) {
                        if (!String.isBlank(loanAcc.loan__Disbursal_Status__c) && (loanAcc.loan__Disbursal_Status__c.equals('Partially Disbursed') || loanAcc.loan__Disbursal_Status__c.equals('Fully Disbursed'))) {
                            
                            for(loan__Periodic_Fee_Setup__c periodicFeeSetup : periodicFeeSetups){
                                if (!periodicFeeSetup.loan__Active__c) {
                                    //Activate H&A, if not active already..
                                    if(hna && 'Home And Auto'.equalsIgnoreCase(periodicFeeSetup.loan__Fee__r.Name)){
                                        periodicFeeSetup.loan__Active__c = hnaSubscribed.is_active__c;
                                        periodicFeeSetup.loan__Next_Recurring_Fee_Date__c = Date.newInstance(3000, 12, 31);
                                        periodicFeeSetup.loan__Amount__c = hnaSubscribed.Subscription_Fees__c;
                                        //create a charge..loan__charge__c.. with amount on LPP Periodic Fee Setup..
                                        insertChargeAndLPT(periodicFeeSetup.loan__Fee__r, loanAcc.id, periodicFeeSetup.loan__Amount__c, false, periodicFeeSetup.id);
                                    }else if(creditOpt && 'Credit Optimizer'.equalsIgnoreCase(periodicFeeSetup.loan__Fee__r.Name)){
                                        periodicFeeSetup.loan__Active__c = creditOptimizerSubscribed.is_active__c;
                                        periodicFeeSetup.loan__Next_Recurring_Fee_Date__c = loanAcc.loan__Next_Due_generation_Date__c;
                                        periodicFeeSetup.Actual_Date__c= loanAcc.loan__Next_Installment_Date__c;
                                        periodicFeeSetup.loan__Amount__c = creditOptimizerSubscribed.Subscription_Fees__c;
                                        
                                        List < loan__Automated_Payment_Setup__c > apsList = loanIdXAPSMap.get(loanAcc.id);
                                        /*loan__Automated_Payment_Setup__c aps = null;
                                        if (apsList != null && apsList.size() > 0) {
                                            aps = apsList.get(0);
                                            aps.loan__Active__c = creditOptimizerSubscribed.is_active__c;
                                            aps.loan__Transaction_Amount__c = periodicFeeSetup.loan__Amount__c;
                                            update aps;
                                        }
                                        if (aps == null) {
                                            insertAPS(loanAcc, periodicFeeSetup.loan__Amount__c, creditOptimizerSubscribed.is_active__c);
                                        }*/
                                    }
                                    
                                }
                            }
                            SecureDML.updateRecords(periodicFeeSetups);
                        } else if (((!String.isBlank(loanAcc.loan__Disbursal_Status__c) && loanAcc.loan__Disbursal_Status__c.equals('Pending Disbursal')) || String.isBlank(loanAcc.loan__Disbursal_Status__c))) {
                            if (loanAcc.loan__Loan_Status__c.equals('Approved')) {
                            }
                        }
                    } else {
                        if (!contaLoanAcc.loan__Loan_Status__c.equals('Closed - Obligations met')) {
                            loanAcc.Contra_Loan_Account__c = contaLoanAcc.id;
                            contaLoanAcc.Contra_Loan_Account__c = loanAcc.id;
                            //update loanAcc;
                            //update contaLoanAcc;
                            throw new AncillaryProductException('Activate Ancillary on Primary Account: ' + contaLoanAcc.Name);
                        }
                    }
                } else if (hna == false || creditOpt == false) {
                    for(loan__Periodic_Fee_Setup__c periodicFeeSetup : periodicFeeSetups){
                        if('Home And Auto'.equalsIgnoreCase(periodicFeeSetup.loan__Fee__r.Name)){
                            periodicFeeSetup.loan__Active__c = hnaSubscribed.is_active__c;
                            periodicFeeSetup.loan__Amount__c = hnaSubscribed.Subscription_Fees__c;
                        }else{
                            periodicFeeSetup.loan__Active__c = creditOptimizerSubscribed.is_active__c;
                            periodicFeeSetup.loan__Amount__c = creditOptimizerSubscribed.Subscription_Fees__c;
                            /*List < loan__Automated_Payment_Setup__c > apsList = loanIdXAPSMap.get(loanAcc.id);
                            loan__Automated_Payment_Setup__c aps = null;
                            if (apsList != null && apsList.size() > 0) {
                                aps = apsList.get(0);
                                aps.loan__Active__c = false;
                                aps.loan__Transaction_Amount__c = periodicFeeSetup.loan__Amount__c;
                                update aps;
                            }*/
                        }      
                    }
                    try {
                        SecureDML.updateRecords(periodicFeeSetups);
                        //update aps;
                    } catch (Exception e) {
                        system.debug('Exception ---' + e);
                    }
                }
            } else if (!loanAcc.Lending_Product_Name__c.contains('Ancillary Product')) {
                if ((hna == true || creditOpt == true) && loanAcc.Contra_Loan_Account__c == null) {
                    //find contra loan, if not make contra loan..

                    List < loan__loan_account__c > contaLoanAccList = accountIdXContraLoanMap.get(loanAcc.loan__Account__r.id);
                    loan__loan_account__c contaLoanAcc = null;
                    if (contaLoanAccList != null && contaLoanAccList.size() > 0) {
                        contaLoanAcc = contaLoanAccList.get(0);
                    }
                    if (contaLoanAcc == null) {
                        //Making Ancillary Product secondary loan Account..
                        //Making Ancillary Product secondary loan Account..
                        contaLoanAcc = createContraLoanAccount(loanAcc);
 
                        //first create disbursal..
                        loan__Loan_Disbursal_Transaction__c ldt = new loan__Loan_Disbursal_Transaction__c();
                        ldt.loan__Loan_Account__c = contaLoanAcc.id;
                        ldt.loan__Financed_Amount__c = 0;
                        ldt.loan__Refinanced_Amount__c = 0;
                        ldt.loan__Disbursed_Amt__c = 0;
                        ldt.loan__Pre_Paid_Fee__c = 0;
                        ldt.loan__Transaction_Creation_Date__c = new loan.GlobalLoanUtilFacade().getCurrentSystemDate();
                        ldt.loan__Mode_of_Payment__c = paymentMode.id;
                        try {
                            SecureDML.insertRecords(ldt);
                        } catch (Exception e) {
                            System.debug('Exception is: ' + e);
                        }
                        loanAcc.Contra_Loan_Account__c = contaLoanAcc.id;
                        update loanAcc;
                        if (!String.isBlank(loanAcc.loan__Disbursal_Status__c)) {
                            if (loanAcc.loan__Disbursal_Status__c.equals('Partially Disbursed') || loanAcc.loan__Disbursal_Status__c.equals('Fully Disbursed')) {
                                //get periodic fee setup, create charge and lpt..

                                for(loan__Periodic_Fee_Setup__c periodicFeeSetup : periodicFeeSetups){
                                    if(!periodicFeeSetup.loan__Active__c){
                                        if (hna && 'Home And Auto'.equalsIgnoreCase(periodicFeeSetup.loan__Fee__r.Name)) {
                                            //Activate H&A, if not active already..
                                            periodicFeeSetup.loan__Active__c = hnaSubscribed.is_active__c;
                                            //periodicFeeSetup.loan__Next_Recurring_Fee_Date__c = loanAcc.loan__First_Installment_Date__c;
                                            periodicFeeSetup.loan__Next_Recurring_Fee_Date__c = Date.newInstance(3000, 12, 31);
                                            periodicFeeSetup.loan__Amount__c = hnaSubscribed.Subscription_Fees__c;
                                        
                                            //create a charge..loan__charge__c.. with amount on LPP Periodic Fee Setup..
                                            insertChargeAndLPT(periodicFeeSetup.loan__Fee__r, loanAcc.id, periodicFeeSetup.loan__Amount__c, false, periodicFeeSetup.id);    
                                        }else if(creditOpt && 'Credit Optimizer'.equalsIgnoreCase(periodicFeeSetup.loan__Fee__r.Name)){
                                            periodicFeeSetup.loan__Active__c = creditOptimizerSubscribed.is_active__c;
                                            periodicFeeSetup.loan__Amount__c = creditOptimizerSubscribed.Subscription_Fees__c;
                                            periodicFeeSetup.loan__Next_Recurring_Fee_Date__c = loanAcc.loan__Next_Due_generation_Date__c;
                                            periodicFeeSetup.Actual_Date__c= loanAcc.loan__Next_Installment_Date__c;                                            List < loan__Automated_Payment_Setup__c > apsList = loanIdXAPSMap.get(loanAcc.id);
                                            /*loan__Automated_Payment_Setup__c aps = null;
                                            if (apsList!=null && apsList.size() > 0) {
                                                aps = apsList.get(0);
                                                aps.loan__Active__c = creditOptimizerSubscribed.is_active__c;
                                                aps.loan__Transaction_Amount__c = periodicFeeSetup.loan__Amount__c;
                                                update aps;
                                            }
                                            if (aps == null) {
                                                insertAPS(loanAcc, periodicFeeSetup.loan__Amount__c, creditOptimizerSubscribed.is_active__c);
                                            }*/
                                        }
                                    }
                                }    
                                try {
                                    SecureDML.updateRecords(periodicFeeSetups);
                                    //update aps;
                                } catch (Exception e) {
                                    system.debug('Exception ---' + e);
                                }
                            }
                        }
                    } else if (contaLoanAcc != null) {
                        
                        contaLoanAcc.Contra_Loan_Account__c = loanAcc.id;
                        loanAcc.Contra_Loan_Account__c = contaLoanAcc.id;
                        SecureDML.updateRecords(contaLoanAcc);
                        SecureDML.updateRecords(loanAcc);

                        //disable periodic setup on secondary, and deactivate APS..if contra was disbursed..
                        if (!String.isBlank(contaLoanAcc.loan__Disbursal_Status__c) && (contaLoanAcc.loan__Disbursal_Status__c.equals('Partially Disbursed') || contaLoanAcc.loan__Disbursal_Status__c.equals('Fully Disbursed'))) {
                            List<loan__Periodic_Fee_Setup__c> contraPeriodicFeeSetups = [SELECT id, name,
                                                                                                loan__Fee__r.Name,
                                                                                                loan__Fee__r.id,
                                                                                                loan__Active__c,
                                                                                                loan__Amount__c 
                                                                                        FROM loan__Periodic_Fee_Setup__c
                                                                                        WHERE loan__Lending_Account__r.id =: contaLoanAcc.id 
                                                                                        AND (loan__Fee__r.Name like '%Home And Auto%' OR loan__Fee__r.Name like '%Credit Optimizer%') ];

                            for(loan__Periodic_Fee_Setup__c periodicFeeSetup : contraPeriodicFeeSetups){
                                if ('Home And Auto'.equalsIgnoreCase(periodicFeeSetup.loan__Fee__r.name)) {
                                    periodicFeeSetup.loan__Active__c = hnaSubscribed.is_active__c;
                                    periodicFeeSetup.loan__Amount__c = hnaSubscribed.Subscription_Fees__c;   
                                }else{
                                    periodicFeeSetup.loan__Active__c = creditOptimizerSubscribed.is_active__c;
                                    periodicFeeSetup.loan__Amount__c = creditOptimizerSubscribed.Subscription_Fees__c;

                                    /*List < loan__Automated_Payment_Setup__c > apsList = loanIdXAPSMap.get(loanAcc.id);
                                    loan__Automated_Payment_Setup__c aps = null;
                                    if (apsList != null && apsList.size() > 0) {
                                        aps = apsList.get(0);
                                        aps.loan__Active__c = false;
                                        aps.loan__Transaction_Amount__c = periodicFeeSetup.loan__Amount__c;
                                        update aps;
                                    }*/
                                
                                }
                            }
                            try {
                                SecureDML.updateRecords(contraPeriodicFeeSetups);
                            } catch (Exception e) {
                                system.debug('Exception ---' + e);
                            }    
                        } else if ((!String.isBlank(contaLoanAcc.loan__Disbursal_Status__c) && contaLoanAcc.loan__Disbursal_Status__c.equals('Pending Disbursal')) || String.isBlank(contaLoanAcc.loan__Disbursal_Status__c)) {
                            contaLoanAcc.loan__Loan_Status__c = 'Approved';
                            SecureDML.updateRecords(contaLoanAcc);

                            
                            //first create disbursal..
                            loan__Loan_Disbursal_Transaction__c ldt1 = new loan__Loan_Disbursal_Transaction__c();
                            ldt1.loan__Loan_Account__c = contaLoanAcc.id;
                            ldt1.loan__Financed_Amount__c = 0;
                            ldt1.loan__Refinanced_Amount__c = 0;
                            ldt1.loan__Disbursed_Amt__c = 0;
                            ldt1.loan__Pre_Paid_Fee__c = 0;
                            ldt1.loan__Transaction_Creation_Date__c = new loan.GlobalLoanUtilFacade().getCurrentSystemDate();
                            ldt1.loan__Mode_of_Payment__c = paymentMode.id;
                            try {
                                SecureDML.insertRecords(ldt1);
                            } catch (Exception e) {

                            }
                        }
                        if (!String.isBlank(loanAcc.loan__Disbursal_Status__c) && (loanAcc.loan__Disbursal_Status__c.equals('Partially Disbursed') || loanAcc.loan__Disbursal_Status__c.equals('Fully Disbursed'))) {
                            for(loan__Periodic_Fee_Setup__c periodicFeeSetup : periodicFeeSetups){
                                if(!periodicFeeSetup.loan__Active__c){
                                    if (hna && 'Home And Auto'.equalsIgnoreCase(periodicFeeSetup.loan__Fee__r.name)) {
                                        //Activate H&A, if not active already..
                                        periodicFeeSetup.loan__Active__c = hnaSubscribed.is_active__c;
                                        periodicFeeSetup.loan__Next_Recurring_Fee_Date__c = Date.newInstance(3000, 12, 31);
                                        periodicFeeSetup.loan__Amount__c = hnaSubscribed.Subscription_Fees__c;

                                        //create a charge..loan__charge__c.. with amount on LPP Periodic Fee Setup..
                                        insertChargeAndLPT(periodicFeeSetup.loan__Fee__r, loanAcc.id, periodicFeeSetup.loan__Amount__c, false,periodicFeeSetup.id);
                                    }else{
                                        periodicFeeSetup.loan__Active__c = creditOptimizerSubscribed.is_active__c;
                                        periodicFeeSetup.loan__Next_Recurring_Fee_Date__c = loanAcc.loan__Next_Due_generation_Date__c;
                                        periodicFeeSetup.Actual_Date__c= loanAcc.loan__Next_Installment_Date__c;
                                        periodicFeeSetup.loan__Amount__c = creditOptimizerSubscribed.Subscription_Fees__c;                            
                                        List < loan__Automated_Payment_Setup__c > apsList = loanIdXAPSMap.get(loanAcc.id);
                                        /*loan__Automated_Payment_Setup__c aps = null;
                                        if (apsList!= null && apsList.size() > 0) {
                                            aps = apsList.get(0);
                                            aps.loan__Active__c = creditOptimizerSubscribed.is_active__c;
                                            aps.loan__Transaction_Amount__c = periodicFeeSetup.loan__Amount__c;
                                            update aps;
                                        }
                                        if (aps == null) {
                                            insertAPS(loanAcc, periodicFeeSetup.loan__Amount__c, creditOptimizerSubscribed.is_active__c);
                                        }*/
                                    }
                                }
                                
                            }
                            try {
                                SecureDML.updateRecords(periodicFeeSetups);
                            } catch (Exception e) {
                                system.debug('Exception ---' + e);
                            }    
                        }
                    } 
                } else if ((creditOpt == true || hna == true) && loanAcc.Contra_Loan_Account__c != null &&
                    (!String.isBlank(loanAcc.loan__Disbursal_Status__c) && (loanAcc.loan__Disbursal_Status__c.equals('Partially Disbursed') || loanAcc.loan__Disbursal_Status__c.equals('Fully Disbursed')))) {
                    //loanAcc.Active_H_A__c = true;

                    for(loan__Periodic_Fee_Setup__c periodicFeeSetup : periodicFeeSetups){
                        if(!periodicFeeSetup.loan__Active__c){
                            if(hna && 'Home And Auto'.equalsIgnoreCase(periodicFeeSetup.loan__Fee__r.name)) {
                                //Activate H&A, if not active already..
                                periodicFeeSetup.loan__Active__c = hnaSubscribed.is_active__c;
                                periodicFeeSetup.loan__Amount__c = hnaSubscribed.Subscription_Fees__c;
                                periodicFeeSetup.loan__Next_Recurring_Fee_Date__c = Date.newInstance(3000, 12, 31);
                                //create a charge..loan__charge__c.. with amount on LPP Periodic Fee Setup..
                                insertChargeAndLPT(periodicFeeSetup.loan__Fee__r, loanAcc.id, periodicFeeSetup.loan__Amount__c, false, periodicFeeSetup.id);  
                            }else if(creditOpt && 'Credit Optimizer'.equalsIgnoreCase(periodicFeeSetup.loan__Fee__r.name)){
                                periodicFeeSetup.loan__Active__c = creditOptimizerSubscribed.is_active__c;
                                periodicFeeSetup.loan__Next_Recurring_Fee_Date__c = loanAcc.loan__Next_Due_generation_Date__c;
                                periodicFeeSetup.Actual_Date__c= loanAcc.loan__Next_Installment_Date__c;
                                periodicFeeSetup.loan__Amount__c = creditOptimizerSubscribed.Subscription_Fees__c;

                                List < loan__Automated_Payment_Setup__c > apsList = loanIdXAPSMap.get(loanAcc.id);
                                /*loan__Automated_Payment_Setup__c aps = null;
                                if (apsList != null && apsList.size() > 0) {
                                    aps = apsList.get(0);
                                    aps.loan__Active__c = creditOptimizerSubscribed.is_active__c;
                                    aps.loan__Transaction_Amount__c = periodicFeeSetup.loan__Amount__c;
                                    update aps;
                                }
                               if (aps == null) {
                                    insertAPS(loanAcc, periodicFeeSetup.loan__Amount__c, creditOptimizerSubscribed.is_active__c);
                                }*/

                            }
                        }
                    }
                    try {
                        SecureDML.updateRecords(periodicFeeSetups);
                    } catch (Exception e) {
                        system.debug('Exception ---' + e);
                    }
                } 
                if ((creditOpt == false || hna == false) &&
                    (!String.isBlank(loanAcc.loan__Disbursal_Status__c) && (loanAcc.loan__Disbursal_Status__c.equals('Partially Disbursed') || loanAcc.loan__Disbursal_Status__c.equals('Fully Disbursed')))) {

                    for(loan__Periodic_Fee_Setup__c periodicFeeSetup : periodicFeeSetups){
                        if ('Home And Auto'.equalsIgnoreCase(periodicFeeSetup.loan__Fee__r.name)) {
                            periodicFeeSetup.loan__Active__c = hnaSubscribed.is_active__c;
                            System.debug('Deactivating Home and Auto');
                            if(hnaSubscribed != null){
                                periodicFeeSetup.loan__Amount__c = hnaSubscribed.Subscription_Fees__c;
                            }    
                            
                        }else if('Credit Optimizer'.equalsIgnoreCase(periodicFeeSetup.loan__Fee__r.name)){
                            periodicFeeSetup.loan__Active__c = creditOptimizerSubscribed.is_active__c;
                            System.debug('Deactivating Credit Optimizer');
                            if(creditOptimizerSubscribed != null){
                                periodicFeeSetup.loan__Amount__c = creditOptimizerSubscribed.Subscription_Fees__c;
                            }

                            /*List < loan__Automated_Payment_Setup__c > apsList = loanIdXAPSMap.get(loanAcc.id);
                            loan__Automated_Payment_Setup__c aps = null;
                            if (apsList!=null && apsList.size() > 0) {
                                aps = apsList.get(0);
                            }
                            if (aps != null) {
                                aps.loan__Active__c = false;
                                aps.loan__Transaction_Amount__c = periodicFeeSetup.loan__Amount__c;
                                update aps;
                            }*/
                        }
                    }
                    try {
                        SecureDML.updateRecords(periodicFeeSetups);
                    } catch (Exception e) {
                        system.debug('Exception ---' + e);
                    }
                }
            }

        }
    }

    public static void insertAPS(loan__loan_Account__c loanAcc, Decimal feeAmount, Boolean markActive) {
        //insert active APS..
        loan__Payment_Mode__c paymentMode = new loan__Payment_Mode__c();
        //create LPT to satisfy above created charge..
        paymentMode = [Select id, name from loan__Payment_Mode__c where Name like '%Cash%'
            limit 1
        ];
        loan__Automated_Payment_Setup__c aps = new loan__Automated_Payment_Setup__c();
        aps.loan__CL_Contract__c = loanAcc.Id;
        aps.loan__Amount_Type_Split_Factor__c = 1;
        aps.loan__Payment_Mode__c = paymentMode.id;
        aps.loan__Debit_Date__c = new loan.GlobalLoanUtilFacade().getCurrentSystemDate();
        aps.loan__Actual_Date__c = new loan.GlobalLoanUtilFacade().getCurrentSystemDate();
        aps.loan__Setup_Date__c = new loan.GlobalLoanUtilFacade().getCurrentSystemDate();
        aps.loan__Active__c = markActive;
        aps.loan__Type__c = 'RECURRING';
        aps.loan__Amount_Type__c = 'FIXED AMOUNT';
        aps.loan__Frequency__c = loanAcc.loan__Frequency_of_Loan_Payment__c;
        aps.loan__Transaction_Amount__c = feeAmount;
        //SecureDML.insertRecords(aps);

    }

    
    public static void insertChargeAndLPT(loan__fee__c loanFee, String loanAccId, Decimal feeAmount, Boolean markPaid, String periodicFeeId) {

        loan__Charge__c charge = new loan__Charge__c();
        charge.loan__Fee__c = loanFee.id;
        charge.loan__Loan_Account__c = loanAccId;
        charge.loan__Date__c = new loan.GlobalLoanUtilFacade().getCurrentSystemDate();
        charge.loan__Total_Amount_Due__c = feeAmount;
        charge.Periodic_Fee_Setup__c = periodicFeeId;
        charge.Is_Created_During_Conversion__c = true;
        SecureDML.insertRecords(charge);

         loan__Charge__c chargeUpdated = [SELECT id, name,
                                                 Periodic_Fee_Setup__r.Current_Base_Amount__c,
                                                 Periodic_Fee_Setup__r.Base_Amount__c,
                                                 Periodic_Fee_Setup__r.Tax__c,
                                                 Periodic_Fee_Setup__r.Tax_Amount__c
                                          FROM loan__Charge__c 
                                          WHERE loan__Loan_Account__c =: loanAccId 
                                          ORDER BY name desc limit 1];
         chargeUpdated.loan__Principal_Due__c = feeAmount;
         loan__Periodic_Fee_Setup__c pfs = chargeUpdated.Periodic_Fee_Setup__r;
         chargeUpdated.Current_Base_Amount__c = (pfs.Current_Base_Amount__c == null || pfs.Current_Base_Amount__c == 0.00) ? pfs.Base_Amount__c : pfs.Current_Base_Amount__c;
         chargeUpdated.Current_Tax__c = pfs.Tax__c;
         chargeUpdated.Current_Tax_Amount__c = pfs.Tax_Amount__c;
         chargeUpdated.loan__Original_Amount__c = chargeUpdated.Current_Base_Amount__c + pfs.Tax_Amount__c;
         SecureDML.updateRecords(chargeUpdated);
        
        /*Commenting Payment Mode FUS-4619 
        List<loan__Payment_Mode__c> paymentModes = new List<loan__Payment_Mode__c>();
        //create LPT to satisfy above created charge..
        
        paymentModes = [Select id, name from loan__Payment_Mode__c where Name =: loanfee.Name limit 1];
        loan__Payment_Mode__c paymentMode = new loan__Payment_Mode__c();
        if(paymentModes.size() == 0){
            paymentMode.Name = loanfee.Name;
            SecureDML.insertRecords(paymentMode);
        }else{
            paymentMode = paymentModes[0];
        }*/
        loan__Loan_Payment_Transaction__c lpt = new loan__Loan_Payment_Transaction__c();
        lpt.loan__Loan_Account__c = loanAccId;
        //lpt.loan__Payment_Mode__c = paymentMode.id;
        lpt.loan__Payment_Application_Mode__c = 'Current Dues';
        lpt.loan__Transaction_Amount__c = feeAmount;
        SecureDML.insertRecords(lpt);
    }

    public static Date updateNextDebitDateOnAPS(String loanId) {
        loan__loan_account__c primary = [Select loan__Next_Installment_Date__c, Contra_Loan_Account__r.id, loan__Maturity_Date_Current__c from
            loan__loan_account__c where id =: loanId 
        ];
        Date nextDue = primary.loan__Next_Installment_Date__c;
        System.debug('Contra_Loan_Account__r.id: ' + primary.Contra_Loan_Account__r.id);
        System.debug('nextDue: ' + nextDue);

        Date nextAmorDate = nextDue;
        Date lastAmorDate = null;

        List < loan__Repayment_Schedule__c > amorToUpdateList = [Select id, name, loan__Due_Date__c from loan__Repayment_Schedule__c where
            loan__Loan_Account__r.id =: primary.Contra_Loan_Account__r.id 
        ];
        if(amorToUpdateList.size() > 0){
        }else{
            lastAmorDate = primary.loan__Maturity_Date_Current__c;
        }
        //update summary..
        list < loan__Repayment_Schedule_Summary__c > summaryList = [Select id, name, loan__RSS_Seq__c, loan__RSS_Repayment_Dt__c from loan__Repayment_Schedule_Summary__c
            where loan__RSS_Loan_Account__r.id =: primary.Contra_Loan_Account__r.id 
        ];
        for (loan__Repayment_Schedule_Summary__c summary: summaryList) {
            if (summary.loan__RSS_Seq__c == 1) {
                summary.loan__RSS_Repayment_Dt__c = nextDue;
            }
            if (summary.loan__RSS_Seq__c == 2) {
                summary.loan__RSS_Repayment_Dt__c = lastAmorDate;
            }
        }
        //update amorToUpdateList;
        update summaryList;
        System.debug(primary.Contra_Loan_Account__r.id);
        List <loan__Automated_Payment_Setup__c> apsList = new List <loan__Automated_Payment_Setup__c>(); 
        if(primary.Contra_Loan_Account__r.id != null){
            apsList = [SELECT id, name
                    FROM loan__Automated_Payment_Setup__c 
                    WHERE loan__CL_Contract__r.id =: primary.Contra_Loan_Account__r.id];
        }            

        /*if(apsList != null && apsList.size()>0){
            for (loan__Automated_Payment_Setup__c aps: apsList) {
                aps.loan__Debit_Date__c = nextDue ;
            }
            update apsList;
        } */  

        //update current maturity date on contraLoanAcc..
        List<loan__loan_account__c> contras = [Select loan__Maturity_Date_Current__c, Contra_Loan_Account__r.id from
            loan__loan_account__c where id =: primary.Contra_Loan_Account__r.id 
        ];
        if(contras.size()>0)
            contras[0].loan__Maturity_Date_Current__c = lastAmorDate;
        //update contra;
        return lastAmorDate;
    }
    
    
    public static void activateAncillariesOnContraLoan(List<Id> loanAccIds) {
        List<loan__loan_account__c> loanAccs = getLoanAccounts(loanAccIds);
        List<loan__loan_account__c> toBeUpdateLoanAccs = new List<loan__loan_account__c>();
        List<loan__Automated_Payment_Setup__c> toBeUpdatedAPS = new List<loan__Automated_Payment_Setup__c>();
        List<loan__Periodic_Fee_Setup__c> toBeUpdatedPFS = new List<loan__Periodic_Fee_Setup__c>();
        Map<Id,List<loan__loan_account__c>> accountIdXContraLoanMap = populateAccountIdXContraLoanAccountMap(loanAccs);
        Map<Id,loan__loan_account__c> loanIdXContraLoanMap = populateLoanXContraLoanMap(loanAccs);
        Set<String> contraLoanIds = new Set<String>();
        loan__Payment_Mode__c paymentMode  = [SELECT id, name 
                                              FROM loan__Payment_Mode__c 
                                              WHERE Name like '%Cash%'  limit 1 ];
        for(loan__loan_account__c contraLoan : loanIdXContraLoanMap.values()){
            contraLoanIds.add(contraLoan.id);
        }
        List<String> contraLoanIdsList = new List<String> ();
        contraLoanIdsList.addAll(contraLoanIds);
        Map<Id,List<loan__Periodic_Fee_Setup__c>> contraLoanXPeriodicFeeMap = populateLoanStandAloneAncillaryMap(contraLoanIdsList);
        Map<Id, List<loan__Automated_Payment_Setup__c>> loanIdXAPSMap = populateLoanAPSMap(contraLoanIdsList);
        for(loan__loan_account__c loanAcc : loanAccs){
            List<CLS_Selected_Ancillary_Product__c> clsSelectedAnciProduct = loanAcc.CLS_Selected_Ancillary_Products__r;
            
            if(clsSelectedAnciProduct.size() > 0){
                for(CLS_Selected_Ancillary_Product__c clsSelectedProd : clsSelectedAnciProduct){
                    if(clsSelectedProd.type__c.equalsIgnoreCase('Protection Plan')){
                        LPP = clsSelectedProd.is_active__c;
                        if(clsSelectedProd.Is_Pre_Paid__c){
                            LPP_prepaid = true;
                        }
                    }else if(clsSelectedProd.type__c.equalsIgnoreCase('Credit Optimizer')){
                        creditOpt = clsSelectedProd.is_active__c;
                        creditOptimizerSubscribed = clsSelectedProd;
                    }else if(clsSelectedProd.type__c.equalsIgnoreCase('Insurance')){
                        hna = clsSelectedProd.is_active__c;
                        hnaSubscribed = clsSelectedProd;
                    }

                }
            }

            if ((creditOpt == true || hna == true)) {
                loan__loan_account__c contaLoanAcc = null;
                Date lastAmorDate = null;
                if (loanAcc.Contra_Loan_Account__c == null) {
                    List < loan__loan_account__c > contaLoanAccList = accountIdXContraLoanMap.get(loanAcc.loan__Account__r.id);
                    if (contaLoanAccList.size() > 0) {
                        contaLoanAcc = contaLoanAccList.get(0);
                    }
                }
                if (loanAcc.Contra_Loan_Account__c != null) {
                    contaLoanAcc = loanIdXContraLoanMap.get(loanAcc.id);
                }
                if (contaLoanAcc != null) {
                    if(contaLoanAcc.loan__Loan_Status__c.contains('Closed - Obligations met')){
                        contaLoanAcc.loan__Loan_Status__c = 'Active - Good Standing';
                        //update contaLoanAcc;
                    }
                    if (!String.isBlank(contaLoanAcc.loan__Disbursal_Status__c) && (contaLoanAcc.loan__Disbursal_Status__c.equals('Partially Disbursed') || contaLoanAcc.loan__Disbursal_Status__c.equals('Fully Disbursed'))) {
                        List<loan__Periodic_Fee_Setup__c> periodicFeeSetupList = contraLoanXPeriodicFeeMap.get(contaLoanAcc.id);
                        
                        List < loan__Automated_Payment_Setup__c > apsList = loanIdXAPSMap.get(contaLoanAcc.id);
                        if(periodicFeeSetupList != null && periodicFeeSetupList.size() > 0){
                            for(loan__Periodic_Fee_Setup__c periodicFeeSetup : periodicFeeSetupList){
                            /* if (periodicFeeSetup != null && creditOpt == true && 'Credit Optimizer'.equalsIgnoreCase(periodicFeeSetup.loan__Fee__r.Name)) {
                                    periodicFeeSetup.loan__Active__c = creditOptimizerSubscribed.is_active__c;
                                    periodicFeeSetup.CLS_Selected_Ancillary_Product__c = creditOptimizerSubscribed.id;
                                    periodicFeeSetup.loan__Amount__c = creditOptimizerSubscribed.Subscription_Fees__c;
                                    periodicFeeSetup.loan__Next_Recurring_Fee_Date__c = loanAcc.loan__Next_Installment_Date__c;
                                    loan__Automated_Payment_Setup__c aps = null;
                                    if (apsList != null && apsList.size() > 0) {
                                        aps = apsList.get(0);
                                        aps.loan__Active__c = true;
                                        aps.loan__Transaction_Amount__c = periodicFeeSetup.loan__Amount__c;
                                        toBeUpdatedAPS.add(aps);
                                    } else {
                                        insertAPS(contaLoanAcc, periodicFeeSetup.loan__Amount__c, true);
                                    }
                                    lastAmorDate = updateNextDebitDateOnAPS(loanAcc.id);
                                    try {
                                        toBeUpdatedPFS.add(periodicFeeSetup);
                                    } catch (Exception e) {
                                        system.debug('Exception ---' + e);
                                    }
                                }*/
                                if (periodicFeeSetup != null && hna == true && 'Home And Auto'.equalsIgnoreCase(periodicFeeSetup.loan__Fee__r.Name)) {
                                    periodicFeeSetup.loan__Active__c = hnaSubscribed.is_active__c;
                                    periodicFeeSetup.CLS_Selected_Ancillary_Product__c = hnaSubscribed.id;
                                    periodicFeeSetup.loan__Next_Recurring_Fee_Date__c = Date.newInstance(3000, 12, 31);
                                    periodicFeeSetup.loan__Amount__c = hnaSubscribed.Subscription_Fees__c;
                                    toBeUpdatedPFS.add(periodicFeeSetup);

                                    //create a charge..loan__charge__c.. with amount on LPP Periodic Fee Setup..
                                    //insertChargeAndLPT(periodicFeeSetup.loan__Fee__r, contaLoanAcc.id, periodicFeeSetup.loan__Amount__c, false);
                                }
                            }
                        }    
                    } else if ((!String.isBlank(contaLoanAcc.loan__Disbursal_Status__c) && contaLoanAcc.loan__Disbursal_Status__c.equals('Pending Disbursal')) || String.isBlank(contaLoanAcc.loan__Disbursal_Status__c)) {
                        contaLoanAcc.loan__Loan_Status__c = 'Approved';
                        
                        contaLoanAcc.Contra_Loan_Account__c = null;

                        loan__Loan_Disbursal_Transaction__c ldt = new loan__Loan_Disbursal_Transaction__c();
                        ldt.loan__Loan_Account__c = contaLoanAcc.id;
                        ldt.loan__Financed_Amount__c = 0;
                        ldt.loan__Refinanced_Amount__c = 0;
                        ldt.loan__Disbursed_Amt__c = 0;
                        ldt.loan__Pre_Paid_Fee__c = 0;
                        ldt.loan__Transaction_Creation_Date__c = new loan.GlobalLoanUtilFacade().getCurrentSystemDate();
                        ldt.loan__Mode_of_Payment__c = paymentMode.id;
                        SecureDML.insertRecords(ldt);

                        
                        
                        lastAmorDate = updateNextDebitDateOnAPS(loanAcc.id);
                        List<loan__Periodic_Fee_Setup__c> periodicFeeSetupList = [SELECT id, name,
                                                                                        loan__Fee__r.Name,
                                                                                        loan__Fee__r.id,
                                                                                        loan__Fee__r.loan__Amount__c,
                                                                                        loan__Lending_Account__r.id,
                                                                                        loan__Active__c, loan__Amount__c 
                                                                                FROM loan__Periodic_Fee_Setup__c
                                                                                WHERE loan__Lending_Account__r.id =: contaLoanAcc.id
                                                                                AND (loan__Fee__r.Name like '%Home And Auto%' OR loan__Fee__r.Name like '%Credit Optimizer%') ];
                        for(loan__Periodic_Fee_Setup__c periodicFeeSetup : periodicFeeSetupList){
                            if(hna && 'Home And Auto'.equalsIgnoreCase(periodicFeeSetup.loan__Fee__r.name)){
                                periodicFeeSetUp.loan__Active__c = hnaSubscribed.is_active__c;
                                periodicFeeSetup.loan__Amount__c = hnaSubscribed.Subscription_Fees__c;
                                periodicFeeSetup.loan__Next_Recurring_Fee_Date__c = Date.newInstance(3000, 12, 31);
                                toBeUpdatedPFS.add(periodicFeeSetup);
                                insertChargeAndLPT(periodicFeeSetup.loan__Fee__r, contaLoanAcc.id, periodicFeeSetup.loan__Amount__c, false,periodicFeeSetup.id);
                            }/*else if('Credit Optimizer'.equalsIgnoreCase(periodicFeeSetup.loan__Fee__r.name)){
                                periodicFeeSetup.loan__Active__c = creditOptimizerSubscribed.is_active__c;
                                periodicFeeSetup.loan__Amount__c = creditOptimizerSubscribed.Subscription_Fees__c;
                                toBeUpdatedPFS.add(periodicFeeSetup);
                                List<loan__Automated_Payment_Setup__c> apsList = [SELECT id, name,
                                                                                 loan__Active__c,
                                                                                 loan__Debit_Date__c
                                                                         FROM loan__Automated_Payment_Setup__c 
                                                                         WHERE loan__CL_Contract__r.id =: contaLoanAcc.id];
                                if (creditOpt == true && apsList != null && apsList.size() > 0) {
                                    loan__Automated_Payment_Setup__c apsNew = apsList[0];
                                    apsNew.loan__Active__c = true;
                                    apsNew.loan__Transaction_Amount__c = creditOptimizerSubscribed.Subscription_Fees__c;
                                    toBeUpdatedAPS.add(apsNew);
                                }else{
                                    insertAPS(contaLoanAcc, periodicFeeSetup.loan__Amount__c, true);
                                }
                            }*/
                        }    
                    }
                    loanAcc.Contra_Loan_Account__c = null;

                    contaLoanAcc.Contra_Loan_Account__c = null;
                    contaLoanAcc.loan__Maturity_Date_Current__c = lastAmorDate;
                    
                    toBeUpdateLoanAccs.add(loanAcc);
                    toBeUpdateLoanAccs.add(contaLoanAcc);
                }
            }
        }
        SecureDML.updateRecords(toBeUpdateLoanAccs);
        SecureDML.updateRecords(toBeUpdatedAPS);
        SecureDML.updateRecords(toBeUpdatedPFS);
    }
    
    
    public static void deActivateAncillariesOnMainLoan(List<Id> loanIds) {
        
        List < loan__Periodic_Fee_Setup__c > periodicFeeSetupList = [SELECT id, name,
                                                                            loan__Fee__r.Name,
                                                                            loan__Fee__r.id,
                                                                            loan__Active__c,
                                                                            loan__Amount__c,
                                                                            CLS_Selected_Ancillary_Product__c,
                                                                            CLS_Selected_Ancillary_Product__r.is_active__c,
                                                                            CLS_Selected_Ancillary_Product__r.Cancellation_Reason__c,
                                                                            CLS_Selected_Ancillary_Product__r.Cancellation_Date__c 
                                                                     FROM loan__Periodic_Fee_Setup__c
                                                                     WHERE loan__Lending_Account__r.id in: loanIds 
                                                                     AND loan__Active__c = true 
                                                                     AND loan__Fee__r.Name in ('Credit Optimizer','Home And Auto','Loan Protection Plan') ];
        system.debug('periodicFeeSetupList******************'+periodicFeeSetupList);
        
        List<CLS_Selected_Ancillary_Product__c> ancillaries = new List<CLS_Selected_Ancillary_Product__c>();     
        if (periodicFeeSetupList.size() > 0) {
            for(loan__Periodic_Fee_Setup__c periodicFeeSetup : periodicFeeSetupList){
                    periodicFeeSetup.loan__Active__c = false;
                    CLS_Selected_Ancillary_Product__c ancillary = periodicFeeSetup.CLS_Selected_Ancillary_Product__r;
                    if(ancillary != null){
                        ancillary.is_active__c = false;
                        ancillary.Cancellation_Reason__c = 'Customer Requested';
                        ancillary.Cancellation_Date__c = new loan.GlobalLoanUtilFacade().getCurrentSystemDate();
                        ancillaries.add(ancillary);
                    }             
            }        
        }
        SecureDML.updateRecords(periodicFeeSetupList);
        SecureDML.updateRecords(ancillaries);
    }

    public static loan__loan_account__c createContraLoanAccount(loan__loan_account__c loanAcc) {
        loan__loan_product__c lendingProduct = [Select id, name, loan__Fee_Set__r.id, RecordTypeId from loan__Loan_Product__c where name like 'Ancillary Product' ];
        RecordType recordType = [Select id, name, IsActive, SobjectType from recordType where name in ('Loan') and SobjectType = 'loan__Loan_Account__c' and IsActive = true ];
        loan__loan_account__c contraLoanAcc = new loan__loan_account__c();
        contraLoanAcc.RecordTypeId = recordType.id;
        contraLoanAcc.loan__Account__c = loanAcc.loan__Account__r.id;
        contraLoanAcc.loan__Contract_Type__c = 'New';
        contraLoanAcc.loan__Loan_Product_Name__c = lendingProduct.id;
        contraLoanAcc.loan__Loan_Status__c = 'Approved';
        contraLoanAcc.loan__Fee_Set__c = lendingProduct.loan__Fee_Set__r.id;
        contraLoanAcc.loan__Loan_Amount__c = 0;
        contraLoanAcc.loan__Second_Installment_Date__c = loanAcc.loan__Second_Installment_Date__c;
        contraLoanAcc.loan__Expected_Disbursal_Date__c = new loan.GlobalLoanUtilFacade().getCurrentSystemDate();
        contraLoanAcc.loan__Expected_Repayment_Start_Date__c = loanAcc.loan__Expected_Repayment_Start_Date__c;
        contraLoanAcc.loan__Number_of_Installments__c = 999;
        contraLoanAcc.loan__Amortization_Schedule_Generated__c = false;
        contraLoanAcc.Contra_Loan_Account__c = loanAcc.id;
        //contraLoanAcc.Active_CO__c = false;
        //contraLoanAcc.Active_H_A__c = false;
        //contraLoanAcc.CO_Subscription_Amount__c = 0;
        //contraLoanAcc.H_A_Subscription_Amount__c = 0;
        contraLoanAcc.loan__Frequency_of_Loan_Payment__c = loanAcc.loan__Frequency_of_Loan_Payment__c;
        loan.BorrowerAPI2 bAPI = loan.APIFactory.getBorrowerAPI2();
        loan__Loan_Account__c loanAccNew = bAPI.createContract(contraLoanAcc,
            null,
            null,
            null,
            null,
            null);
        System.debug(loanAccNew.id);
        return loanAccNew;
    }

    
    
    public static List<loan__loan_account__c> getLoanAccounts(List<String> loanIds){
        List < loan__loan_account__c > loanAccList = [Select id, name,
                                                                RecordTypeId,
                                                                loan__Periodic_Fee__c,
                                                                loan__Maturity_Date_Current__c,
                                                                Contra_Loan_Account__r.id, 
                                                                loan__Last_Installment_Date__c, 
                                                                loan__First_Installment_Date__c,
                                                                loan__Account__r.id, loan__Loan_Status__c,
                                                                Lending_Product_Name__c, 
                                                                Contra_Loan_Account__r.loan__Loan_Status__c, 
                                                                loan__Loan_Purpose__r.id, 
                                                                loan__Disbursal_Status__c, 
                                                                loan__Branch__r.id, 
                                                                Contra_Loan_Account__r.Name,
                                                                loan__Next_Installment_Date__c,
                                                                application__c, 
                                                                loan__Frequency_of_Loan_Payment__c,
                                                                loan__Expected_Repayment_Start_Date__c,
                                                                loan__Next_Due_generation_Date__c,
                                                                loan__Second_Installment_Date__c, 
                                                                (SELECT id,name,
                                                                        Account__c, 
                                                                        Application__c,
                                                                        Is_Active__c,
                                                                        Is_Pre_Paid__c,
                                                                        Type__c,
                                                                        Subscription_Fees__c  
                                                                FROM CLS_Selected_Ancillary_Products__r 
                                                                WHERE ( type__c=: 'Protection Plan' OR type__c =: 'Credit Optimizer' OR type__c =: 'Insurance' )) 
                                                        FROM loan__loan_account__c where id =: loanIds ];
        return loanAccList;                                                
    }
    
    public static Map<Id,loan__Periodic_Fee_Setup__c> populateLoanLPPMap(List<String> loanIds){
        List<loan__Periodic_Fee_Setup__c> periodicFeeSetups = [Select id, name,
                                                                        loan__Fee__r.Name,
                                                                        loan__Fee__r.id,
                                                                        loan__Active__c,
                                                                        LPP_Prepaid__c,
                                                                        loan__Amount__c,
                                                                        loan__Lending_Account__r.id
                                                                FROM loan__Periodic_Fee_Setup__c
                                                                WHERE loan__Lending_Account__r.id in : loanIds 
                                                                AND loan__Fee__r.Name like '%Loan Protection Plan%' ];
        Map<Id,loan__Periodic_Fee_Setup__c> idXLPPPeriodicFeeMap = new Map<Id,loan__Periodic_Fee_Setup__c>();
        for(loan__Periodic_Fee_Setup__c periodicFeeSetup : periodicFeeSetups){
            idXLPPPeriodicFeeMap.put(periodicFeeSetup.loan__Lending_Account__r.id,periodicFeeSetup);
        }
        return idXLPPPeriodicFeeMap;
    }

    public static Map<Id,loan__Repayment_Schedule__c> populateAmzScheduleMap(List<String> loanAccIds){
        List<loan__Repayment_Schedule__c> amortizationScheduleList = [SELECT id, name,
                                                                            loan__Due_Date__c,
                                                                            loan__Loan_Account__r.id  
                                                                      FROM loan__Repayment_Schedule__c
                                                                      WHERE loan__Loan_Account__r.id in: loanAccIds 
                                                                      AND loan__Is_Archived__c = false 
                                                                      ORDER BY loan__Due_Date__c Desc Limit 1];
        Map<Id,loan__Repayment_Schedule__c> loanIdXAmzScheduleMap = new Map<Id,loan__Repayment_Schedule__c>();
        for(loan__Repayment_Schedule__c amortizationSchedule : amortizationScheduleList){
            loanIdXAmzScheduleMap.put(amortizationSchedule.loan__Loan_Account__r.id,amortizationSchedule);
        }
        return loanIdXAmzScheduleMap;
    }

    public static Map<Id,List<loan__Periodic_Fee_Setup__c>> populateLoanStandAloneAncillaryMap(List<String> loanIds){
        List<loan__Periodic_Fee_Setup__c> periodicFeeSetups = [SELECT id, name,
                                                                        loan__Fee__r.Name,
                                                                        loan__Fee__r.id,
                                                                        loan__Fee__r.loan__Amount__c,
                                                                        loan__Lending_Account__r.id,
                                                                        loan__Active__c, loan__Amount__c 
                                                                FROM loan__Periodic_Fee_Setup__c
                                                                WHERE loan__Lending_Account__r.id in: loanIds
                                                                AND (loan__Fee__r.Name like '%Home And Auto%' OR loan__Fee__r.Name like '%Credit Optimizer%') ];
        Map<Id,List<loan__Periodic_Fee_Setup__c>> idXStandAlonePeriodicFeeMap = new Map<Id,List<loan__Periodic_Fee_Setup__c>>();
        for(loan__Periodic_Fee_Setup__c periodicFeeSetup : periodicFeeSetups){
            List<loan__Periodic_Fee_Setup__c> periodicFeeList = new List<loan__Periodic_Fee_Setup__c>();
            if(idXStandAlonePeriodicFeeMap.get(periodicFeeSetup.loan__Lending_Account__r.id) != null){
                periodicFeeList = idXStandAlonePeriodicFeeMap.get(periodicFeeSetup.loan__Lending_Account__r.id);
            }
            periodicFeeList.add(periodicFeeSetup);
            idXStandAlonePeriodicFeeMap.put(periodicFeeSetup.loan__Lending_Account__r.id,periodicFeeList);
        }
        return idXStandAlonePeriodicFeeMap;
    }

    public static Map<Id,List<loan__Loan_Account__c>> populateAccountIdXNonAncillaryLoanMap(List<loan__loan_account__c> loanAccs){
        Set<Id> accIds = new Set<Id>();
        SET<Id> loanIds = new Set<Id>();
        for(loan__loan_account__c la : loanAccs){
            accIds.add(la.loan__Account__r.id);
            loanIds.add(la.Id);
        }
        List<loan__Loan_Account__c> contraLoanAccounts = [SELECT id, name,
                                                                 loan__Disbursal_Status__c,
                                                                 loan__Account__r.id,
                                                                 loan__Loan_Status__c 
                                                         FROM loan__loan_account__c
                                                         WHERE loan__Account__r.id in: accIds 
                                                         AND (NOT Lending_Product_Name__c like '%Ancillary Product%')
                                                         AND Id not in: loanIds  
                                                         AND loan__Loan_Status__c not in ('Closed - Obligations met', 'Closed- Written Off') ];

        Map<Id,List<loan__Loan_Account__c>> accountIdXContraLoanMap = new Map<Id,List<loan__Loan_Account__c>>();
        for(loan__Loan_Account__c contraLoanAccount : contraLoanAccounts){
            List<loan__Loan_Account__c> contraLoanList = new List<loan__Loan_Account__c>();
            if(accountIdXContraLoanMap.get(contraLoanAccount.loan__Account__r.id) != null){
                contraLoanList = accountIdXContraLoanMap.get(contraLoanAccount.loan__Account__r.id);
            }
            contraLoanList.add(contraLoanAccount);
            accountIdXContraLoanMap.put(contraLoanAccount.loan__Account__r.id,contraLoanList);
        }
        return accountIdXContraLoanMap;
    }

    public static Map<Id,List<loan__Automated_Payment_Setup__c>> populateLoanAPSMap(List<String> loanIds){
        List<loan__Automated_Payment_Setup__c> apsList = [SELECT id, name, 
                                                                 loan__Active__c,
                                                                 loan__CL_Contract__r.id,
                                                                 loan__Payment_Mode__c   
                                                         FROM loan__Automated_Payment_Setup__c 
                                                         WHERE loan__CL_Contract__r.id in: loanIds ];
        
        Map<Id,List<loan__Automated_Payment_Setup__c>> loanIdXAPSMap = new Map<Id,List<loan__Automated_Payment_Setup__c>>();
        for(loan__Automated_Payment_Setup__c aps : apsList){
            List<loan__Automated_Payment_Setup__c> apses = new List<loan__Automated_Payment_Setup__c>();
            if(loanIdXAPSMap.get(aps.loan__CL_Contract__r.id) != null){
                apses = loanIdXAPSMap.get(aps.loan__CL_Contract__r.id);
            }
            apses.add(aps);
            loanIdXAPSMap.put(aps.loan__CL_Contract__r.id,apses);
        }
        return loanIdXAPSMap;  
    }

    public static Map<Id,List<loan__Loan_Account__c>> populateAccountIdXContraLoanAccountMap(List<loan__loan_account__c> loanAccs){
        Set<Id> accIds = new Set<Id>();
        for(loan__loan_account__c la : loanAccs){
            accIds.add(la.loan__Account__r.id);
        }
        List<loan__Loan_Account__c> contraLoanAccounts = [SELECT id, name, 
                                                                loan__Disbursal_Status__c,
                                                                loan__Loan_Status__c,
                                                                loan__Account__r.id 
                                                        FROM loan__loan_account__c 
                                                        WHERE Lending_Product_Name__c like '%Ancillary Product%'
                                                        AND loan__Account__r.id in: accIds ];
        Map<Id,List<loan__Loan_Account__c>> accountIdXContraLoanMap = new Map<Id,List<loan__Loan_Account__c>>();
        for(loan__Loan_Account__c contraLoanAccount : contraLoanAccounts){
            List<loan__Loan_Account__c> contraLoanList = new List<loan__Loan_Account__c>();
            if(accountIdXContraLoanMap.get(contraLoanAccount.loan__Account__r.id) != null){
                contraLoanList = accountIdXContraLoanMap.get(contraLoanAccount.loan__Account__r.id);
            }
            contraLoanList.add(contraLoanAccount);
            accountIdXContraLoanMap.put(contraLoanAccount.loan__Account__r.id,contraLoanList);
        }
        return accountIdXContraLoanMap;
    //Raising Dummy Build request1
    }

    public static Map<Id,loan__loan_account__c> populateLoanXContraLoanMap(List<loan__loan_account__c> loanAccs){
        Set<Id> loanAccIds = new Set<Id>();
        for(loan__loan_account__c la : loanAccs){
            loanAccIds.add(la.id);
        }
        List<loan__loan_account__c> loanAccounts = [SELECT id, name,
                                                                Contra_Loan_Account__r.id,
                                                                Contra_Loan_Account__r.name,
                                                                Contra_Loan_Account__r.loan__Disbursal_Status__c,
                                                                Contra_Loan_Account__r.loan__Loan_Status__c,
                                                                Contra_Loan_Account__r.loan__Frequency_of_Loan_Payment__c 
                                                            FROM loan__loan_account__c 
                                                            WHERE Contra_Loan_Account__r.Lending_Product_Name__c like '%Ancillary Product%' 
                                                            AND id in: loanAccIds ];
        
        Map<Id,loan__loan_account__c> loanXContraLoanMap = new Map<Id,loan__loan_account__c>();
        for(loan__loan_account__c loanAcc : loanAccounts){
            loanXContraLoanMap.put(loanAcc.id,loanAcc.Contra_Loan_Account__r);
        }
        return loanXContraLoanMap;
    }
}