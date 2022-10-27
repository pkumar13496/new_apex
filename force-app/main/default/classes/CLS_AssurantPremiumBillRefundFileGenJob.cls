/*************************************************************************************************************************************************************************************************************************************
* Class   : CLS_AssurantPremiumBillRefundFileGenJob
* Purpose : Dynamic job to consume Mulesoft system API and send request mapping to generate large files
* Company : GoEasy
* Author  : Shubham
*************************************************************************************************************************************************************************************************************************************/

global class CLS_AssurantPremiumBillRefundFileGenJob extends clcommon.DynamicJob implements Database.AllowsCallouts{
    
    global static String NAME = 'CLS_LargeFileGenJob';
    loan.GlobalLoanUtilFacade loanFacade = new loan.GlobalLoanUtilFacade();
    Date currentSystemDate = loanFacade.getCurrentSystemDate();  
    private static final String TEST_EXCEPTION = 'Test Exception';
    
    global  CLS_AssurantPremiumBillRefundFileGenJob(){
        super ( NAME, null ) ;                
    }
    
    global  CLS_AssurantPremiumBillRefundFileGenJob ( String query ) {
        super ( NAME, query ) ;
    }  
    
    global override void doExecute ( SchedulableContext sc ) {
        CLS_AssurantPremiumBillRefundFileGenJob job = new CLS_AssurantPremiumBillRefundFileGenJob();
        Database.executeBatch ( job ) ;
    }    
    
    
    global override void doInitialize() {} 
    global override void doStart(Database.BatchableContext bc) { }
    global override void doFinish ( Database.BatchableContext bc) { } 
    
    global override void doExecute(Database.BatchableContext bc, List<sObject> scope) {
        
        try{    
            String requeststructure1 = CLS_MuleSoftDocGenServiceAdapterCallOut.generateRequestForLargeFileGeneration(CLS_MuleSoftFileGenServiceConstant.RECORD_NAME_LPP_ASS_PBR);
            
        } catch ( Exception ex ) {
            System.debug('Error'+ex.getMessage()+' AT '+ex.getLineNumber() + ' ONN ' +ex.getStackTraceString() + ' FOR ' + ex.getTypeName());
        }                   
    }
    
    global override String getRuntimeQuery() {
        
        String reqConfigMapping = 'SELECT Id, Name FROM Account LIMIT 1';
        
        return reqConfigMapping;
    }
    
}