/********************************************************************************************************************************************************************************
 * Class   : CLS_APSWrapperHandler
 * Company : GoEasy
 * Author  : Ajeet
 ********************************************************************************************************************************************************************************/
global class CLS_APSWrapperHandler {
    
    public static String callAPSCreationFromProduct(CLS_APSWrapperAPI.bluepayWrapperRequest bpInstance){
        
        System.debug('bpInstance'+bpInstance);
        
        //String likeString = '%'+bpInstance.loanNumber+'%';
        String bluePayRecordName = CLS_Constants.BLUEPAY_RECORD_NAME;
        
        loan__Payment_Mode__c bluePayRecord = [Select Id, Name from loan__Payment_Mode__c where Name=:bluePayRecordName ];
        loan__Loan_Account__c contractRec =[Select id,loan__Account__c,Name,loan__First_Installment_Date__c,loan__Frequency_of_Loan_Payment__c from loan__Loan_Account__c where Id=:bpInstance.loanNumber  Limit 1];
        
        if(contractRec.loan__Account__c != null){
            return createbankAccount(contractRec,bpInstance.bluepayToken,bluePayRecord.Id);
        }else{
            return CLS_Constants.ACC_ID_EMPTY;
        }
        
    }
    public static String createbankAccount(loan__Loan_Account__c contractRec,String bpToken,String bpPaymentId){
        loan__Bank_Account__c bnacc = new loan__Bank_Account__c();
        // Below one is required, But we will not get this from Mule
        bnacc.loan__Bank_Account_Number__c = CLS_Constants.ACC_NUMBER;
        bnacc.loan__Account__c = contractRec.loan__Account__c;
        bnacc.loan__Account_Type__c= CLS_Constants.ACC_TYPE;
        bnacc.loan__Active__c = true;
        bnacc.loan__Bank_Name__c = CLS_Constants.ACC_BANK_NAME;
        bnacc.BluePay_Token__c = bpToken;
        SecureDML.insertRecords(bnacc);
        
        loan__Automated_Payment_Setup__c apsInstance = new loan__Automated_Payment_Setup__c();
        apsInstance.loan__CL_Contract__c = contractRec.Id;
        apsInstance.loan__Amount_Type__c = CLS_Constants.APS_AMOUNT_TYPE;
        apsInstance.loan__Debit_Date__c = contractRec.loan__First_Installment_Date__c;//Loan Contract Next Due Date/First Payment Date
        apsInstance.loan__Setup_Date__c = System.today();
        apsInstance.loan__Payment_Mode__c = bpPaymentId;// BluePayId
        apsInstance.loan__Frequency__c = contractRec.loan__Frequency_of_Loan_Payment__c;//Loan Contract Frequency
        apsInstance.loan__Type__c = CLS_Constants.APS_LOAN_TYPE;
        apsInstance.loan__Bank_Account__c = bnacc.Id;
        apsInstance.loan__Active__c = true;
        SecureDML.insertRecords(apsInstance);
        
        
        return bnacc.id;
    }
    
    class apsRequestWrapper {
        public Decimal transactionAmount;//From LPT, last bil
        public Date debitDate;//Loan Contract Next Due Date/First Payment Date
        public Date setupDate;//System.today();
        public String paymentModeName;//BluePay
        public String frequency;//""Loan Contract Frequency
        public String amountType;//Last Billed Amount
        public String type;//RECURRING
    }
}