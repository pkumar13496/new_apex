public class CheckAncillaryProductPFSTriggerHandler {

    static List<loan__Periodic_Fee_Setup__c> pfsToInsert = new List<loan__Periodic_Fee_Setup__c>();
    //static List<loan__Periodic_Fee_Setup__c> pfsItemsToInsert = new List<loan__Periodic_Fee_Setup__c>();
    static Set < String > loanAccIds = new Set < String > ();
    static Set < String > loanFeeIds = new Set < String > ();
    static Map < String, loan__loan_account__c > loanAccSubscription = new Map < String, loan__loan_account__c > ();
    static Map < String, String > loanFeeMap = new Map < String, String > ();
    static Map <String, List<loan__Periodic_Fee_Setup__c>> loanXperiodicFeeSetups = new Map <String, List<loan__Periodic_Fee_Setup__c>>();
    static Map < ID, genesis__applications__c> applications = new Map < ID, genesis__applications__c>();
    static Map<String, List<loan__Repayment_Schedule__c>> accAmortMap = new Map<String, List<loan__Repayment_Schedule__c>>();
    
    public static void checkAncillaryProductSubscription(List < loan__Periodic_Fee_Setup__c > pfsList) {
        
        if (!(loan.CustomSettingsUtil.getOrgParameters().loan__Disable_Triggers__c)) {
            // If you want this for update operation, then check update as well in the below if statement
            if (trigger.isBefore && trigger.isInsert) {
                //get ids of all loan accounts for which periodic fee setup are getting inserted..
                Map <String, List<loan__Periodic_Fee_Setup__c>> loanXperiodicFeeSetups = new Map <String, List<loan__Periodic_Fee_Setup__c>>();
                for (loan__Periodic_Fee_Setup__c pfsNew: pfsList) {
                    if (pfsNew.loan__Lending_Account__c != null) {
                        loanAccIds.add(pfsNew.loan__Lending_Account__c);
                        loanFeeIds.add(pfsNew.loan__Fee__c);
                        pfsToInsert.add(pfsNew);
                        List<loan__Periodic_Fee_Setup__c> pfList = new List<loan__Periodic_Fee_Setup__c>();
                        if(loanXperiodicFeeSetups.get(pfsNew.loan__Lending_Account__c) != null){
                            pfList = loanXperiodicFeeSetups.get(pfsNew.loan__Lending_Account__c);
                        }
                       
                        pfList.add(pfsNew);
                       
                        loanXperiodicFeeSetups.put(pfsNew.loan__Lending_Account__c,pfList);
                    }
                }
                populateMaps(loanAccIds, loanFeeIds);
                //loan__loan_account__c loanAcc;
                for (loan__loan_account__c loanAcc: loanAccSubscription.values()) {
                   //loanAcc = loanAccSubscription.get(pfsNew.loan__Lending_Account__c);
                    List<CLS_Selected_Ancillary_Product__c> subscribedProducts = null;
                    Map<String,CLS_Selected_Ancillary_Product__c> typeXSubscribedAncillaryMap= new Map<String, CLS_Selected_Ancillary_Product__c>();
                    System.debug(loanAcc.Application__r.id);
                    if(applications.get(loanAcc.Application__r.id) != null ){
                        subscribedProducts = applications.get(loanAcc.Application__r.id).CLS_Selected_Ancillary_Products__r;
                        System.debug(subscribedProducts);
                    }
                    if(subscribedProducts != null){
                        for(CLS_Selected_Ancillary_Product__c subscribedProduct : subscribedProducts){
                            typeXSubscribedAncillaryMap.put(subscribedProduct.Type__c,subscribedProduct);
                        }
                    }
                    List<loan__Periodic_Fee_Setup__c> periodicFeeSetUpList = loanXperiodicFeeSetups.get(loanAcc.id);
                    List<CLS_Selected_Ancillary_Product__c> toBeUpdatedAncillaries = new List<CLS_Selected_Ancillary_Product__c>();
                    if(periodicFeeSetUpList != null && periodicFeeSetUpList.size() > 0){
                        for(loan__Periodic_Fee_Setup__c periodicFeeSetUp : periodicFeeSetUpList){
                            System.debug('loanAcc is: ' + loanAcc);
                            periodicFeeSetUp.Current_Base_Amount__c = periodicFeeSetUp.base_Amount__c;
                            periodicFeeSetUp.Current_Tax__c = periodicFeeSetUp.tax__c;
                            periodicFeeSetUp.Current_Tax_Amount__c = periodicFeeSetUp.tax_amount__c;
                            if (!loanAcc.Lending_Product_Name__c.contains('Ancillary Product')) {
                                if (loanFeeMap.get(periodicFeeSetUp.loan__Fee__c).contains('Loan Protection Plan')) {
                                    CLS_Selected_Ancillary_Product__c protectionPlan = typeXSubscribedAncillaryMap.get('Protection Plan');
                                    System.debug('protectionPlan.....'+protectionPlan);
                                    if(protectionPlan != null){
                                        if(protectionPlan.Effective_Date__c == null){
                                            protectionPlan.Effective_Date__c = loanAcc.loan__Next_Installment_Date__c;
                                            toBeUpdatedAncillaries.add(protectionPlan);
                                        }
                                        periodicFeeSetUp.loan__Active__c = protectionPlan.is_active__c;
                                        periodicFeeSetUp.CLS_Selected_Ancillary_Product__c = protectionPlan.id;
                                        periodicFeeSetUp.loan__Amount__c = protectionPlan.Subscription_Fees__c;
                                    }else{
                                        periodicFeeSetUp.loan__Active__c = false;
                                    }    
                                    if (protectionPlan != null && periodicFeeSetUp.loan__Active__c && protectionPlan.Is_Pre_Paid__c) {
                                        periodicFeeSetUp.loan__Next_Recurring_Fee_Date__c = loanAcc.loan__Next_Due_generation_Date__c;
                                        periodicFeeSetup.Actual_Date__c= loanAcc.loan__Next_Installment_Date__c;
                                        List<loan__Repayment_Schedule__c> amortizationScheduleList = new List<loan__Repayment_Schedule__c>();
                                        if(accAmortMap.containsKey(loanAcc.id)){
                                            amortizationScheduleList = accAmortMap.get(loanAcc.id);
                                        } 
                                        if(amortizationScheduleList.size() > 0 ){
                                            for(loan__Repayment_Schedule__c amortizationSchedule : amortizationScheduleList){
                                                periodicFeeSetUp.Fee_End_Date__c = amortizationSchedule.loan__Due_Date__c;
                                            }
                                        }
                                        insertChargeAndLPT(periodicFeeSetUp.loan__Fee__c, loanAcc.id, periodicFeeSetUp.loan__Amount__c, false,periodicFeeSetUp.id);    
                                    }
                                }
                                if (loanFeeMap.get(periodicFeeSetUp.loan__Fee__c).contains('Credit Optimizer')) {
                                    //pfsNew.loan__Active__c = subs.getActiveCO();
                                    CLS_Selected_Ancillary_Product__c creditOptimizer = typeXSubscribedAncillaryMap.get('Credit Optimizer');
                                    if(creditOptimizer != null){
                                        if(creditOptimizer.Effective_Date__c == null){
                                            creditOptimizer.Effective_Date__c = loanAcc.loan__Next_Installment_Date__c;
                                            toBeUpdatedAncillaries.add(creditOptimizer);
                                        }
                                        periodicFeeSetUp.loan__Active__c = creditOptimizer.is_active__c;
                                        periodicFeeSetUp.CLS_Selected_Ancillary_Product__c = creditOptimizer.id;
                                        periodicFeeSetUp.loan__Amount__c = creditOptimizer.Subscription_Fees__c;
                                    }else{
                                        periodicFeeSetUp.loan__Active__c = false;
                                    }   
                                    //pfsNew.loan__Active__c = loanAcc.Active_CO__c;
                                    periodicFeeSetUp.loan__Next_Recurring_Fee_Date__c = loanAcc.loan__Next_Due_generation_Date__c;
                                    periodicFeeSetup.Actual_Date__c= loanAcc.loan__Next_Installment_Date__c;
                                    /*if (periodicFeeSetUp.loan__Active__c) {
                                        insertAPS(loanAcc, periodicFeeSetUp.loan__Amount__c, true);
                                    }*/
    
                                }
                                if (loanFeeMap.get(periodicFeeSetUp.loan__Fee__c).contains('Home And Auto')) {
                                    CLS_Selected_Ancillary_Product__c insurance = typeXSubscribedAncillaryMap.get('Insurance');
                                    System.debug('Insurance..'+insurance);
                                    if(insurance != null){
                                        if(insurance.Effective_Date__c == null){
                                            insurance.Effective_Date__c = loanAcc.loan__Next_Installment_Date__c;
                                            toBeUpdatedAncillaries.add(insurance);
                                        }
                                        periodicFeeSetUp.loan__Active__c = insurance.is_active__c;
                                        periodicFeeSetUp.CLS_Selected_Ancillary_Product__c = insurance.id;
                                        periodicFeeSetUp.loan__Amount__c = insurance.Subscription_Fees__c;
                                    }else{
                                        periodicFeeSetUp.loan__Active__c = false;
                                    }   
                                    //pfsNew.loan__Active__c = loanAcc.Active_H_A__c;
                                    periodicFeeSetUp.loan__Next_Recurring_Fee_Date__c = Date.newInstance(3000, 12, 31);
                                    List<loan__Repayment_Schedule__c> amortizationScheduleList = new List<loan__Repayment_Schedule__c>();
                                    if(accAmortMap.containsKey(loanAcc.id)){
                                        amortizationScheduleList = accAmortMap.get(loanAcc.id);
                                    }
                                    if(amortizationScheduleList.size() > 0){
                                        for(loan__Repayment_Schedule__c amortizationSchedule : amortizationScheduleList){
                                            periodicFeeSetUp.Fee_End_Date__c = amortizationSchedule.loan__Due_Date__c;
                                        }
                                    }
    
                                    //create a charge..loan__charge__c.. with amount on LPP Periodic Fee Setup..                     
                                    if (periodicFeeSetUp.loan__Active__c) {
                                        insertChargeAndLPT(periodicFeeSetUp.loan__Fee__c, loanAcc.id, periodicFeeSetUp.loan__Amount__c, false,periodicFeeSetUp.id);
                                    }
    
                                }
    
                            } else if (loanAcc.Lending_Product_Name__c.contains('Ancillary Product')) {
    
                                if (loanFeeMap.get(periodicFeeSetUp.loan__Fee__c).contains('Credit Optimizer')) {
                                    CLS_Selected_Ancillary_Product__c creditOptimizer = typeXSubscribedAncillaryMap.get('Credit Optimizer');
                                    if(creditOptimizer != null){
                                        if(creditOptimizer.Effective_Date__c == null){
                                            creditOptimizer.Effective_Date__c = loanAcc.loan__Next_Installment_Date__c;
                                            toBeUpdatedAncillaries.add(creditOptimizer);
                                        }
                                        periodicFeeSetUp.loan__Active__c = creditOptimizer.is_active__c;
                                        periodicFeeSetUp.CLS_Selected_Ancillary_Product__c = creditOptimizer.id;
                                        periodicFeeSetUp.loan__Amount__c = creditOptimizer.Subscription_Fees__c;
                                    }else{
                                        periodicFeeSetUp.loan__Active__c = false;
                                    }   
                                   
                                    periodicFeeSetUp.loan__Next_Recurring_Fee_Date__c = loanAcc.loan__Next_Due_generation_Date__c;
                                    periodicFeeSetup.Actual_Date__c= loanAcc.loan__Next_Installment_Date__c;
    
                                    if (loanAcc.Contra_Loan_Account__c == null && periodicFeeSetUp.loan__Active__c) {
                                        //insert active APS..
                                        //insertAPS(loanAcc, periodicFeeSetUp.loan__Amount__c, true);
                                    } else if (loanAcc.Contra_Loan_Account__c == null && !periodicFeeSetUp.loan__Active__c) {
    
                                        //insertAPS(loanAcc.Id, pfsNew.loan__Amount__c, false);
                                    } else if (loanAcc.Contra_Loan_Account__c != null && !periodicFeeSetUp.loan__Active__c) {
    
                                        //insert deactive APS..
                                        //insertAPS(loanAcc, periodicFeeSetUp.loan__Amount__c, false);
                                    }
                                } 
                                if (loanFeeMap.get(periodicFeeSetUp.loan__Fee__c).contains('Home And Auto')) {
                                    CLS_Selected_Ancillary_Product__c insurance = typeXSubscribedAncillaryMap.get('Insurance');
                                    if(insurance != null){
                                        if(insurance.Effective_Date__c == null){
                                            insurance.Effective_Date__c = loanAcc.loan__Next_Installment_Date__c;
                                            toBeUpdatedAncillaries.add(insurance);
                                        }
                                        periodicFeeSetUp.loan__Active__c = insurance.is_active__c;
                                        periodicFeeSetUp.CLS_Selected_Ancillary_Product__c = insurance.id;
                                        periodicFeeSetUp.loan__Amount__c = insurance.Subscription_Fees__c;
                                    }else{
                                        periodicFeeSetUp.loan__Active__c = false;
                                    }   
                                    //periodicFeeSetUp.loan__Active__c = loanAcc.Active_H_A__c;
                                    //periodicFeeSetUp.loan__Amount__c = loanAcc.H_A_Subscription_Amount__c;
                                    periodicFeeSetUp.loan__Next_Recurring_Fee_Date__c = Date.newInstance(3000, 12, 31);
                                    //Populate Fee end date..
                                    List<loan__Repayment_Schedule__c> amortizationScheduleList = new List<loan__Repayment_Schedule__c>();
                                    if(accAmortMap.containsKey(loanAcc.id)){
                                        amortizationScheduleList = accAmortMap.get(loanAcc.id);
                                    }
                                    if(amortizationScheduleList.size() > 0){
                                        for(loan__Repayment_Schedule__c amortizationSchedule : amortizationScheduleList){
                                            periodicFeeSetUp.Fee_End_Date__c = amortizationSchedule.loan__Due_Date__c;
                                        }
                                    }
    
    
                                    if (loanAcc.Contra_Loan_Account__c == null && periodicFeeSetUp.loan__Active__c) {
    
                                        //insert active APS..
                                        insertChargeAndLPT(periodicFeeSetUp.loan__Fee__c, loanAcc.id, periodicFeeSetUp.loan__Amount__c, false,periodicFeeSetUp.id);
    
                                    } else if (loanAcc.Contra_Loan_Account__c == null && !periodicFeeSetUp.loan__Active__c) {
    
                                        //insertChargeAndLPT(pfsNew.loan__Fee__c, loanAcc.id, pfsNew.loan__Amount__c, false);
                                    } else if (loanAcc.Contra_Loan_Account__c != null && !periodicFeeSetUp.loan__Active__c) {
    
                                        //insert deactive APS..
                                    }
    
                                }
                            }
                        }
                    }
                    SecureDML.updateRecords(toBeUpdatedAncillaries);    
                }
            }
        }
    }

    public static void populateMaps(Set < String > loanAccIds, Set < String > loanFeeIds) {
        System.debug('loanAccIds: ' + loanAccIds);
        List < loan__loan_account__c > loanAccnts = [Select id, loan__First_Installment_Date__c,
                                                            loan__Next_Installment_Date__c,
                                                            Lending_Product_Name__c, 
                                                            loan__loan_Status__c,
                                                            Application__r.id,
                                                            loan__Next_Due_generation_Date__c,
                                                            loan__Frequency_of_Loan_Payment__c,
                                                            Contra_Loan_Account__r.id
                                                    FROM loan__loan_account__c where id in: loanAccIds ];
        //Get List of Subscribed products for a loan
        List<String> applicationList = new List<String>();                                            
        for(loan__loan_account__c loanAccount : loanAccnts){
            applicationList.add(loanAccount.Application__r.id);
        }

        applications = new Map<id,genesis__applications__c> ([ SELECT id,name, 
                                                                      (SELECT id,name,
                                                                              Account__c,
                                                                              Application__c,
                                                                              Is_Active__c,
                                                                              Is_Pre_Paid__c,
                                                                              Type__c,
                                                                              Effective_Date__c,
                                                                              Subscription_Fees__c  
                                                                       FROM CLS_Selected_Ancillary_Products__r
                                                                       WHERE is_active__c =: true)
                                                               FROM genesis__applications__c   
                                                               WHERE id in : applicationList ]) ;                                     
        //populating loanAccSubscription map..
        for (loan__loan_account__c loanAcc: loanAccnts) {
            loanAccSubscription.put(loanAcc.id, loanAcc);
        }
        List < loan__Fee__c > loanFeeList = [Select id, name, loan__Amount__c from loan__Fee__c where id in: loanFeeIds ];
        for (loan__Fee__c loanFee: loanFeeList) {
            loanFeeMap.put(loanFee.id, loanFee.name);
        }
        List<loan__Repayment_Schedule__c> amortizationScheduleList = new List<loan__Repayment_Schedule__c>();
        amortizationScheduleList = [SELECT id, name, 
                                            loan__Due_Date__c, 
                                            loan__Loan_Account__r.id 
                                    FROM loan__Repayment_Schedule__c 
                                    WHERE loan__Loan_Account__r.id in: loanAccIds 
                                    AND loan__Is_Archived__c = false 
                                    ORDER BY loan__Due_Date__c Desc Limit 1 Offset 1 ];
          
        if(amortizationScheduleList.size() > 0){   
            System.debug('In update PFS process builder amortizationScheduleList: '+amortizationScheduleList ); 
            for(loan__Repayment_Schedule__c amort : amortizationScheduleList){
                List<loan__Repayment_Schedule__c> amortList = accAmortMap.get(amort.loan__Loan_Account__r.id); 
                    if(amortList == null){
                        amortList = new List<loan__Repayment_Schedule__c>();
                    }
                    amortList.add(amort);
                    accAmortMap.put(amort.loan__Loan_Account__r.id, amortList );
            }
        } 
    }
    
    public static void insertAPS(loan__loan_Account__c loanAcc, Decimal feeAmount, Boolean markActive) {
        //insert active APS..
        /*loan__Payment_Mode__c paymentMode = new loan__Payment_Mode__c();
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
        //SecureDML.insertRecords(aps);*/
    }
    
    public static void insertChargeAndLPT(String loanFee, String loanAccId, Decimal feeAmount, Boolean markPaid,String periodicFeeId) {

        loan__Charge__c charge = new loan__Charge__c();
        charge.loan__Fee__c = loanFee;
        charge.loan__Loan_Account__c = loanAccId;
        charge.loan__Date__c = new loan.GlobalLoanUtilFacade().getCurrentSystemDate();
        charge.loan__Total_Amount_Due__c = feeAmount;
        charge.Periodic_Fee_Setup__c = periodicFeeId;
        charge.Is_Created_During_Conversion__c = true;
        //charge.loan__Paid_Amount__c = feeAmount;
        //charge.loan__Original_Amount__c = feeAmount;

        SecureDML.insertRecords(charge);
        
       loan__Charge__c chargeUpdated = [SELECT id, name,
                                                Periodic_Fee_Setup__r.Current_Base_Amount__c,
                                                Periodic_Fee_Setup__r.Base_Amount__c,
                                                Periodic_Fee_Setup__r.Tax__c,
                                                Periodic_Fee_Setup__r.Tax_Amount__c
                                        FROM loan__Charge__c 
                                        WHERE loan__Loan_Account__c =: loanAccId 
                                        ORDER BY name desc limit 1];
        //chargeUpdated.loan__Principal_Due__c = feeAmount;
        loan__Periodic_Fee_Setup__c pfs = chargeUpdated.Periodic_Fee_Setup__r;
        if(pfs != null){
            chargeUpdated.Current_Base_Amount__c = (pfs.Current_Base_Amount__c == null || pfs.Current_Base_Amount__c == 0.00) ? pfs.Base_Amount__c : pfs.Current_Base_Amount__c;
            chargeUpdated.Current_Tax__c = pfs.Tax__c;
            chargeUpdated.Current_Tax_Amount__c = pfs.Tax_Amount__c;
            chargeUpdated.loan__Original_Amount__c = chargeUpdated.Current_Base_Amount__c + pfs.Tax_Amount__c;
        }    
        chargeUpdated.loan__Principal_Due__c = feeAmount;
        SecureDML.updateRecords(chargeUpdated);

        /*loan__Payment_Mode__c paymentMode = new loan__Payment_Mode__c();
        //create LPT to satisfy above created charge..
        paymentMode = [Select id, name from loan__Payment_Mode__c where Name like '%Cash%'
            limit 1
        ];*/
        loan__fee__c fee = [Select id,name from loan__fee__c where id =: loanFee];
        //Removing Payment Mode from LPT FUS-4619
        /*List<loan__Payment_Mode__c> paymentModes = new List<loan__Payment_Mode__c>();
        //create LPT to satisfy above created charge..
        paymentModes = [Select id, name from loan__Payment_Mode__c where Name =: fee.Name limit 1];
        loan__Payment_Mode__c paymentMode = new loan__Payment_Mode__c();
        if(paymentModes.size() == 0){
            paymentMode.Name = fee.Name;
            SecureDML.insertRecords(paymentMode);
        }else{
            paymentMode = paymentModes[0];
        }*/
        loan__Loan_Payment_Transaction__c lpt = new loan__Loan_Payment_Transaction__c();
        lpt.loan__Loan_Account__c = loanAccId;
        //lpt.loan__Payment_Mode__c = paymentMode.id;
        lpt.loan__Transaction_Amount__c = feeAmount;
        lpt.loan__Payment_Application_Mode__c = 'Current Dues';
        SecureDML.insertRecords(lpt);
    }
}