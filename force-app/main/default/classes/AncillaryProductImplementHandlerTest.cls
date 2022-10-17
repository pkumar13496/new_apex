@isTest
public class AncillaryProductImplementHandlerTest{
    
    @TestSetup
    static void createSeedData(){
        
        loan.TestHelper.createSeedDataForTesting();
        Account acc = new Account() ;
        acc.Name = 'Test Acc';
        acc.ownerID = UserInfo.getUserId() ;
        SecureDML.insertRecords(acc);
        
        loan__Loan_Purpose__c dummyLoanPurpose = loan.TestHelper.createLoanPurpose();
        
        loan__Office_Name__c dummyOffice = loan.testHelper.createOffice('dummyOffice');
        
        loan__Client__c dummyClient = loan.testhelper.createClient ( dummyOffice ) ;
        
        loan__MF_Account__c mfAccount = loan.TestHelper.createMFAccount ( 'XXXAccountForTest', 'Type' ) ;
        loan__Currency__c curr = loan.TestHelper.createCurrency() ;
        
        List<loan__Fee__c> feeList = new List<loan__Fee__c>() ;
        loan__Fee__c dummyFee = new loan__Fee__c() ;
        dummyFee.name = 'test';
        dummyFee.loan__State__c = 'Active';
        dummyFee.loan__Time_of_charge__c = 'Time of Charge';
        dummyFee.loan__Include_In_Dues__c = true;
        dummyFee.loan__Fee_Calculation_Method__c = 'FLAT';
        dummyFee.loan__Amount__c = 100;
        dummyFee.loan__Periodic_Fee_Amount_Type__c = 'Amount';
        
        feeList.add ( dummyFee ) ;
        
        loan__Fee__c dummyLPPFee = new loan__Fee__c() ;
        dummyLPPFee.name = 'Loan Protection Plan';
        dummyLPPFee.loan__State__c = 'Active';
        dummyLPPFee.loan__Time_of_charge__c = 'Periodic Fees';
        dummyLPPFee.loan__Include_In_Dues__c = true;
        dummyLPPFee.loan__Fee_Calculation_Method__c = 'Fixed';
        dummyLPPFee.loan__Amount__c = 25;
        dummyLPPFee.loan__Periodic_Fee_Amount_Type__c = 'Per Period Amount';
        dummyLPPFee.loan__Periodic_Charge_Start_Basis__c = 'First Payment Date';
        feeList.add ( dummyLPPFee) ;
        
        loan__Fee__c dummyFeePPP = new loan__Fee__c() ;
        dummyFeePPP.name = 'Payment Protection Plan';
        dummyFeePPP.loan__State__c = 'Active';
        dummyFeePPP.loan__Time_of_charge__c = 'Time of Charge';
        dummyFeePPP.loan__Include_In_Dues__c = true;
        dummyFeePPP.loan__Fee_Calculation_Method__c = 'FLAT';
        dummyFeePPP.loan__Amount__c = 100;
        dummyFeePPP.loan__Periodic_Fee_Amount_Type__c = 'Amount';
        
        feeList.add ( dummyFeePPP ) ;
        SecureDML.insertRecords(feeList);
        
        
        
        loan__Fee_Set__c dummyFeeSet = loan.TestHelper.createFeeSet() ;
        
        loan__Fee_Junction__c dummyFeeJunction = loan.TestHelper.createFeeJunction ( dummyLPPFee, dummyFeeSet ) ;
        
        loan__Payment_Mode__c paymentMode = new loan__Payment_Mode__c ( name = 'Cash' ) ;
        SecureDML.insertRecords(paymentMode);
        
        loan__Loan_Product__c loanProduct  = new loan__Loan_Product__c() ;  
        loanProduct.Name = 'test loan Product';
        loanProduct.loan__Interest_Calculation_Method__c = 'FLAT';
        loanProduct.loan__Frequency_of_Loan_Payment__c = 'Monthly';
        loanProduct.loan__Loan_Product_Type__c = 'Loan';
        loanProduct.loan__Time_Counting_Method__c = 'Month And Days';
        loanProduct.loan__Status__c = 'Active';
        loanProduct.loan__Max_Loan_Amount__c = 100000;
        loanProduct.loan__Fee_Set__c = dummyFeeSet.id;
        loanProduct.loan__Min_Interest_Rate__c = 5;
        loanProduct.loan__Max_Interest_Rate__c = 20;
        loanProduct.loan__Default_Interest_Rate__c = 10;
        
        SecureDML.insertRecords(loanProduct);
        
        loan__loan_Account__c loanAccount = loan.TestHelper.createLoanAccountForAccountObj ( loanProduct , acc, dummyFeeSet,  dummyLoanPurpose,  dummyOffice ) ;
        
        
        loan__Payment_Mode__c payment = [ SELECT 
                                         ID , 
                                         Name
                                         FROM 
                                         loan__Payment_Mode__c 
                                         LIMIT 1] ;
        
        Loan__Loan_Disbursal_Transaction__c disTxn = new Loan__Loan_Disbursal_Transaction__c ( loan__Loan_Account__c = loanAccount.Id, loan__Disbursed_Amt__c = loanAccount.loan__loan_Amount__c, loan__Mode_of_Payment__c = payment.id ) ;
        loan.LoanDisbursalActionAPI api = new loan.LoanDisbursalActionAPI ( disTxn ) ;
        loanAccount = api.disburseLoanAccount (); 
        
        
        loan__Fee_Payment__c feePayment = new loan__Fee_Payment__c() ;
        
        feePayment.loan__Transaction_Date__c = System.today() ;
        
        feePayment.loan__Transaction_Amount__c = 1000;
        SecureDML.insertRecords(feePayment);
        
        
        loan__Other_Transaction__c otherTxn = new loan__Other_Transaction__c();
        otherTxn.loan__Txn_Date__c = date.today();
        otherTxn.loan__Loan_Account__c = loanAccount.id;
        otherTxn.loan__Transaction_Type__c = 'Reschedule' ;
        SecureDML.insertRecords(otherTxn);
        
        
        loanAccount.loan__Pmt_Amt_Cur__c = 100;
        loanAccount.loan__Loan_Product_Name__c = loanProduct.Id;
        loanAccount.loan__Account__c = acc.Id;
        loanAccount.loan__Payment_Amount__c  =100;
        //loanAccount.loan__Loan_Status__c = 'Closed - Obligations met' ;
        //loanAccount.ECT_Approved_Program__c = 'Term Extension';
        loanAccount.loan__Frequency_of_Loan_Payment__c = 'Monthly'; 
        loanAccount.loan__Number_of_Installments__c = 24;
        //loanAccount.loan__Application_Date__c = Date.newInstance(2017, 12, 4);
        loanAccount.loan__Application_Date__c = new loan.GlobalLoanUtilFacade().getCurrentSystemDate();
        loanAccount.loan__Expected_Disbursal_Date__c= new loan.GlobalLoanUtilFacade().getCurrentSystemDate();
        loanAccount.loan__Interest_Type__c = 'Fixed';
        loanAccount.loan__Loan_Amount__c = 20000; 
        loanAccount.loan__Expected_Repayment_Start_Date__c = new loan.GlobalLoanUtilFacade().getCurrentSystemDate().addMonths(1);
        loanAccount.loan__Contract_Type__c = 'New';
        loanAccount.loan__Interest_Type__c = 'Fixed';
        //loanAccount.Number_of_ECT_s_Applied__c = 1; 
        loanAccount.loan__First_Installment_Date__c =  new loan.GlobalLoanUtilFacade().getCurrentSystemDate();
        loanAccount.loan__Maturity_Date_Current__c =  new loan.GlobalLoanUtilFacade().getCurrentSystemDate();
        loanAccount.loan__Last_Installment_Date__c =  new loan.GlobalLoanUtilFacade().getCurrentSystemDate();
        SecureDML.updateRecords(loanAccount);
        system.debug('loanAccount*********'+loanAccount);
        
    }
  /*  static testMethod void testActivatingLPPPrepaid() {
        
        Test.startTest();
        
        loan__loan_account__c loanAccount = [Select id, name, Active_LPP__c, LPP_Prepaid__c, loan__Maturity_Date_Current__c from loan__loan_account__c];
        loanAccount.Active_LPP__c = true;
        loanAccount.LPP_Prepaid__c = true;
        SecureDML.updateRecords(loanAccount);
        
        loan__Periodic_Fee_Setup__c periodicFeeSetup = [Select id, name, loan__Active__c , LPP_Prepaid__c from loan__Periodic_Fee_Setup__c where 
                                                        loan__Lending_Account__r.id =:loanAccount.id and loan__Fee__r.Name like '%Loan Protection Plan%'];
        periodicFeeSetup.loan__Active__c = false;
        SecureDML.updateRecords(periodicFeeSetup);
        
        List<ID> loanAccList = new List<ID>();
        loanAccList.add(loanAccount.id);
        AncillaryProductImplementationHandler.processAncillaryProduct(loanAccList);
        Test.stopTest();
        
        loan__loan_account__c updatedLoanAccount = [Select id, name, Active_LPP__c, LPP_Prepaid__c from loan__loan_account__c];
        
        loan__Periodic_Fee_Setup__c updatedPeriodicFeeSetup = [Select id, name, loan__Active__c , LPP_Prepaid__c from loan__Periodic_Fee_Setup__c where 
                                                               loan__Lending_Account__r.id =:loanAccount.id and loan__Fee__r.Name like '%Loan Protection Plan%'];
        
        System.assertEquals(true, updatedLoanAccount.Active_LPP__c);
        System.assertEquals(true, updatedLoanAccount.LPP_Prepaid__c);
        System.assertEquals(true, updatedPeriodicFeeSetup.loan__Active__c);
        System.assertEquals(true, updatedPeriodicFeeSetup.LPP_Prepaid__c);
        
    } */
    static testMethod void testprocessClosedWrittenOff() {
        Test.startTest();
        loan__loan_account__c loanAccount = [Select id, loan__Loan_Status__c, CO_Subscription_Amount__c, H_A_Subscription_Amount__c, name, loan__Account__r.id, loan__Maturity_Date_Current__c from loan__loan_account__c limit 1];
        system.debug('loanAccount*********'+loanAccount);
        loanAccount.loan__Loan_Status__c = 'Closed- Written Off';
        loanAccount.Active_CO__c = TRUE;
        loanAccount.Active_H_A__c = TRUE;
        loan__Fee__c loanFee = [select Id, Name from loan__Fee__c limit 1];
        loanFee.Name = 'Credit Optimizer';
        SecureDML.updateRecords(loanFee);
        List < loan__Periodic_Fee_Setup__c > periodicFeeSetup = [Select id, name, loan__Fee__r.Name, loan__Fee__r.id, loan__Active__c, loan__Amount__c from loan__Periodic_Fee_Setup__c where 
                                                        loan__Lending_Account__r.id =:loanAccount.id and loan__Active__c = true and loan__Fee__r.Name like '%Credit Optimizer%'];
        system.debug([Select id, name, loan__Fee__r.Name, loan__Fee__r.id, loan__Active__c, loan__Amount__c from loan__Periodic_Fee_Setup__c where 
                                                        loan__Lending_Account__r.id =:loanAccount.id and loan__Active__c = true and loan__Fee__r.Name like '%Credit Optimizer%']);
        system.debug('periodicFeeSetup******************'+periodicFeeSetup);
        AncillaryProductImplementationHandler.processClosedWrittenOff(loanAccount);
        Test.stopTest();
        
    }
    static testMethod void testcreateContraLoanAccount() {
        Test.startTest();
        loan__loan_account__c loanAccount = [Select id, CO_Subscription_Amount__c, H_A_Subscription_Amount__c, name, loan__Account__r.id, loan__Maturity_Date_Current__c from loan__loan_account__c limit 1];
        system.debug('loanAccount*********'+loanAccount);
        loan__Loan_Product__c productDetail = [select id, name from loan__Loan_Product__c limit 1];
        productDetail.Name = 'Ancillary Product';
        SecureDML.updateRecords(productDetail);
        loan__loan_account__c loanAccNew = AncillaryProductImplementationHandler.createContraLoanAccount(loanAccount);
        Test.stopTest();
        system.debug('loanAccNew**********'+loanAccNew);
        //System.assertEquals(false, loanAccNew.Active_CO__c);
        //System.assertEquals(false, loanAccNew.Active_H_A__c);
    }
}