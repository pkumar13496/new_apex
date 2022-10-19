@isTest
public class CLS_LoanTransactionTriggerTest {
    @testSetup
    static void setup() {
        Test.startTest();
        loan.testHelper.createSeedDataForTesting() ;
        Account acc = new Account() ;
        acc.Name = 'Test Acc';
        acc.ownerID = UserInfo.getUserId() ;
        insert acc;
        
        genesis__Org_Parameters__c orgParams = new genesis__Org_Parameters__c();
        orgParams.genesis__FinancialCalculatorVersion__c = 3.10;
        insert orgParams;
        
        genesis__Company__c company = TestHelper.createCompany('Dickinson');
        System.debug(company.Id);
        
        
        genesis__Rate_Card_Setup_Header__c rateCard = TestHelper.createRateCard(company.Id);
        
        genesis__Rate_Card_Setup_Detail__c rateCardSetup = TestHelper.createRateCardSetup(rateCard.Id);
        
        clcommon__Legal_Entity__c legalEntityType = TestHelper.createLegalEntityType('Individual');
        
        Contact contact = TestHelper.createContact(acc.Id,legalEntityType.Id);
        
        clcommon__CL_Product__c product = TestHelper.createCLProduct('Personal Unsecured Loan');
        
        
        
        
        
        loan__Loan_Purpose__c dummyLoanPurpose = loan.TestHelper.createLoanPurpose () ;
        loan__Office_Name__c dummyOffice = loan.TestHelper.createOffice ( 'dummyOffice' ) ;
        loan__Client__c dummyClient = loan.testhelper.createClient ( dummyOffice ) ;
        loan__MF_Account__c mfAccount = loan.TestHelper.createMFAccount ( 'XXXAccountForTest', 'Type' ) ;
        loan__Currency__c curr = loan.TestHelper.createCurrency() ;
        
        List<loan__Fee__c> feeList = new List<loan__Fee__c>() ;
        loan__Fee__c dummyFee = new loan__Fee__c() ;
        dummyFee.name = 'Credit Monitoring';
        dummyFee.loan__State__c = 'Active';
        dummyFee.loan__Time_of_charge__c = 'Time of Charge';
        dummyFee.loan__Include_In_Dues__c = true;
        dummyFee.loan__Fee_Calculation_Method__c = 'FLAT';
        dummyFee.loan__Amount__c = 100;
        dummyFee.loan__Periodic_Fee_Amount_Type__c = 'Amount';
        
        feeList.add ( dummyFee ) ;
        
        loan__Fee__c dummyFeePPP = new loan__Fee__c() ;
        dummyFeePPP.name = 'Payment Protection Plan';
        dummyFeePPP.loan__State__c = 'Active';
        dummyFeePPP.loan__Time_of_charge__c = 'Time of Charge';
        dummyFeePPP.loan__Include_In_Dues__c = true;
        dummyFeePPP.loan__Fee_Calculation_Method__c = 'FLAT';
        dummyFeePPP.loan__Amount__c = 100;
        dummyFeePPP.loan__Periodic_Fee_Amount_Type__c = 'Amount';
        
        feeList.add ( dummyFeePPP ) ;
        insert feeList;
        
        
        
        loan__Fee_Set__c dummyFeeSet = loan.TestHelper.createFeeSet() ;
        loan__Fee_Junction__c dummyFeeJunction = loan.TestHelper.createFeeJunction ( dummyFee, dummyFeeSet ) ;
        loan__Payment_Mode__c paymentMode = new loan__Payment_Mode__c ( name = 'Cash' ) ;
        insert paymentMode;
        
        loan__Loan_Product__c loanProduct  = new loan__Loan_Product__c() ;  
        loanProduct.Name = 'Test';
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
        
        insert loanProduct;
        
        loan__loan_Account__c loanAccount = loan.TestHelper.createLoanAccountForAccountObj ( loanProduct , acc, dummyFeeSet,  dummyLoanPurpose,  dummyOffice ) ;
        
        loanAccount.loan__Pmt_Amt_Cur__c = 100;
        loanAccount.loan__Payment_Amount__c  =100;
        loanAccount.loan__Loan_Status__c = 'Approved' ;
        loanAccount.loan__loan_Amount__c = 10000;
        loanAccount.loan__Frequency_of_Loan_Payment__c = 'Monthly';
        update loanAccount; 
        
        
        loan__Payment_Mode__c payment = [ SELECT 
                                         ID , 
                                         Name
                                         FROM 
                                         loan__Payment_Mode__c 
                                         LIMIT 1] ;
        loan__Bank_Account__c bankRec = new loan__Bank_Account__c(loan__Account__c=acc.id,loan__Bank_Name__c='HSBC',loan__Bank_Account_Number__c='123457890');
        insert bankRec;
        
        loan__Payment_Mode__c paymentModeRec =  new loan__Payment_Mode__c(name='BluePay');
        insert paymentModeRec;
        
        loan__Other_Transaction__c oltrecord = new loan__Other_Transaction__c();
        oltrecord.loan__Txn_Amt__c=100.00;
        oltrecord.loan__Txn_Date__c=System.today();
        oltrecord.loan__Transaction_Type__c ='AdHoc Refund';
        oltrecord.Payment_Mode__c = paymentModeRec.Id;
        oltrecord.loan__Bank_Account__c = bankRec.Id;
        oltrecord.loan__Loan_Account__c = loanAccount.Id;
        
        insert oltrecord;
        
        clcommon__Party__c partyRec = new clcommon__Party__c();
        partyRec.CL_Contract__c = loanAccount.Id;
        
        insert partyRec;
        
        CLL_CustomerAndLoanContarctFileUploadFie__c accCustomSettingData = new CLL_CustomerAndLoanContarctFileUploadFie__c();
        accCustomSettingData.Name='Customer';
        accCustomSettingData.Field_List__c='Loan Refrence Id,Deceased ?,Deceased Date';
        insert accCustomSettingData;
        
        CLL_CustomerAndLoanContarctFileUploadFie__c contractCustomSettingData = new CLL_CustomerAndLoanContarctFileUploadFie__c();
        contractCustomSettingData.Name='Contract';
        contractCustomSettingData.Field_List__c='Loan Refrence Id,Consumer Proposal ?,Consumer Proposal Date,Sold ?,Bankruptcy ?,Bankruptcy Date';
        insert contractCustomSettingData;
        
        Test.stopTest();
        
        
    }
    public static testmethod void testLoanContract(){
        Test.startTest();
        loan__Loan_Account__c loanAccount =[Select id,loan__Account__c,Name from loan__Loan_Account__c Limit 1];
        String accCsvStr = 'Loan Refrence Id,Deceased ?,Deceased Date\n '+loanAccount.Name+',Deceased With Insurance,7/7/2020';   
        String contractCsvStr = 'Loan Refrence Id,Consumer Proposal ?,Consumer Proposal Date,Sold ?,Bankruptcy ?,Bankruptcy Date\n '+loanAccount.Name+',Yes,7/7/2020,Yes,Yes,7/7/2020';   
        
        //.public static successAndfailures processData(String fileData,String sobjectName,List<String> fields) {
        CLO_CustomerDocumentUpload.processData(contractCsvStr,'Contract',new List<String>{'Loan Refrence Id','Consumer Proposal ?','Consumer Proposal Date','Sold ?','Bankruptcy ?','Bankruptcy Date'});
        CLO_CustomerDocumentUpload.processData(accCsvStr,'Customer',new List<String>{'Loan Refrence Id','Deceased ?','Deceased Date'});
        CLO_CustomerDocumentUpload.updateSObject(new List<sObject>{loanAccount});
        CLO_CustomerDocumentUpload.getFieldList();
        CLO_CustomerDocumentUpload.getDocTemplate('Customer');
        CLO_CustomerDocumentUpload.getDocTemplate('Contract');
        Test.stopTest();
        
        
    }
    
}