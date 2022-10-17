public class AncillaryProductConversionHandler{

    public static void subscribeAncillary(String applicationId,String loanAccId, List<CLS_Selected_Ancillary_Product__c> subscribedProducts){
        /*List<CLS_Selected_Ancillary_Product__c> subscribedProducts = [SELECT id,name,
                                                                             type__c,
                                                                             Subscription_Fees__c,
                                                                             Is_Pre_Paid__c,
                                                                             Is_Active__c,
                                                                             CL_Contract__c,
                                                                             Current_Amount__c,
                                                                             Current_Tax__c 
                                                                             //Base_Subscription_Amount__c,
                                                                             //Base_Subscription_Tax__c 
                                                                      FROM CLS_Selected_Ancillary_Product__c
                                                                      WHERE Application__r.id =: applicationId];*/
        
        
        loan__loan_Account__c loanAcc = [SELECT id,name,
                                         loan__Next_Due_Generation_Date__c       
                                         FROM loan__loan_Account__c
                                         WHERE id =: loanAccId];

        /*if(loanAccs.size() > 0){
            loan__loan_Account__c loanAcc = loanAccs[0];*/
            if(subscribedProducts.size() > 0){
                for(CLS_Selected_Ancillary_Product__c subscribedProduct : subscribedProducts ){
                       subscribedProduct.Is_Active__c = true;
                       subscribedProduct.CL_Contract__c = loanAccId;
                       subscribedProduct.Current_Amount__c = 0;
                       subscribedProduct.Current_Tax__c = 0;
                       if(subscribedProduct.Effective_Date__c == null){
                           subscribedProduct.Effective_Date__c = new loan.GlobalLoanUtilFacade().getCurrentSystemDate();
                       }
                }
                SecureDML.updateRecords(subscribedProducts);
            }
        //}
    }
}