/**
 * AncillaryProductUtils.cls
 * @description Used by originate in branch transfer flow
 * @author Asif Bhat, Q2
 * @date  2020-Nov-26

 History
 *  2021-June-07 | | Asif bhat | Removed commented out code, fixed alingments
 */
public class AncillaryProductUtils{
    
    public static void processTaxRateChange(Map<String,String> contractXprovince, Map<Id,Id> contractIdXlogId){
        Date currentSystemDate = new loan.GlobalLoanUtilFacade().getCurrentSystemDate();
        List<loan__loan_account__c> contracts = [SELECT id,name,province__c,
                                                        (SELECT id,name, 
                                                                Base_Subscription_Amount__c, 
                                                                Base_Subscription_Tax__c, 
                                                                Current_Amount__c, 
                                                                current_tax__c,
                                                                type__c,
                                                                subscription_fees__c   
                                                         FROM CLS_Selected_Ancillary_Products__r),
                                                         (SELECT id,name
                                                         FROM loan__charges__r
                                                         WHERE loan__Waive__c = false 
                                                         AND loan__Paid__c = false)
                                                FROM loan__loan_account__c where id in: contractXprovince.keyset() ];
                                                
        List<CLS_Credit_Optimizer_Configuration__c> coConfigs = [SELECT  id,name,
                                                                         Tax__c,
                                                                         Tax_Percentage__c,
                                                                         Region__c  
                                                                FROM CLS_Credit_Optimizer_Configuration__c 
                                                                WHERE Effective_Date__c <=: currentSystemDate 
                                                                AND region__c in: contractXprovince.values()  
                                                                ORDER BY Effective_Date__c Desc];
       
       Map<String,CLS_Credit_Optimizer_Configuration__c> provinceXCoConfigMap = new Map<String,CLS_Credit_Optimizer_Configuration__c>();
       for(CLS_Credit_Optimizer_Configuration__c coConfig : coConfigs){
           provinceXCoConfigMap.put(coConfig.region__c,coConfig);
       }                                                        
       List<CLS_Protection_Plan_Configuration__c> lppConfigs = [SELECT id,name,
                                                                       Region__c,
                                                                       Monthly__c,
                                                                       Biweekly__c,
                                                                       Semi_Monthly__c,
                                                                       Weekly__c 
                                                                FROM CLS_Protection_Plan_Configuration__c
                                                                WHERE Effective_Date__c <=: currentSystemDate 
                                                                AND region__c in: contractXprovince.values() 
                                                                ORDER BY Effective_Date__c Desc];
       Map<String,CLS_Protection_Plan_Configuration__c> provinceXlppConfigMap = new Map<String,CLS_Protection_Plan_Configuration__c>();
       for(CLS_Protection_Plan_Configuration__c lppConfig : lppConfigs){
           provinceXlppConfigMap.put(lppConfig.region__c,lppConfig);
       }
       if(contracts.size() > 0){
           List<CLS_Selected_Ancillary_Product__c> toBeUpdatedAP = new List<CLS_Selected_Ancillary_Product__c>();
           List<Branch_Transfer_Charge__c> btcList = new List<Branch_Transfer_Charge__c>();
           for(loan__loan_account__c loanAcc : contracts){
               List<CLS_Selected_Ancillary_Product__c> subscribedProducts = loanAcc.CLS_Selected_Ancillary_Products__r;
               for(CLS_Selected_Ancillary_Product__c subscribedProduct : subscribedProducts){
                   if('Insurance'.equalsIgnoreCase(subscribedProduct.type__c)){
                       continue;
                   }else if('Credit Optimizer'.equalsIgnoreCase(subscribedProduct.type__c)){
                      if(provinceXCoConfigMap.get(loanAcc.province__c) != null){
                          CLS_Credit_Optimizer_Configuration__c config = provinceXCoConfigMap.get(loanAcc.province__c);
                          if(subscribedProduct.Current_Amount__c == null || subscribedProduct.Current_Amount__c == 0.00){
                              subscribedProduct.Current_Amount__c = 0.00;
                          }    
                          subscribedProduct.current_tax__c = ((subscribedProduct.Current_Amount__c) * config.Tax_Percentage__c )/100;
                          subscribedProduct.subscription_fees__c = subscribedProduct.Current_Amount__c + subscribedProduct.current_tax__c;
                          toBeUpdatedAP.add(subscribedProduct);
                      }
                   }else if('Protection Plan'.equalsIgnoreCase(subscribedProduct.type__c)){
                      if(provinceXCoConfigMap.get(loanAcc.province__c) != null){
                          CLS_Protection_Plan_Configuration__c config = provinceXlppConfigMap.get(loanAcc.province__c);
                          if(subscribedProduct.Current_Amount__c == null || subscribedProduct.Current_Amount__c == 0.00){
                              subscribedProduct.Current_Amount__c = 0.00;
                          }    
                          subscribedProduct.subscription_fees__c = config.Monthly__c;
                          toBeUpdatedAP.add(subscribedProduct);
                      }
                   }
               }
               List<loan__charge__c> charges = loanAcc.loan__charges__r;
               if(charges.size()>0){
                   for(loan__charge__c charge : charges){
                       Branch_Transfer_Charge__c btc = new Branch_Transfer_Charge__c();
                       btc.Charge__c = charge.id;
                       btc.CL_Contract__c = loanAcc.id;
                       btc.Loan_Branch_Transfer_Log__c = contractIdXlogId.get(loanAcc.id);
                       btcList.add(btc);
                   }
               }
           }
           SecureDML.updateRecords(toBeUpdatedAP);
           SecureDML.insertRecords(btcList);
       }
    }
    
    public static void handleRefinancedCOCancellation(List<String> loanIds){
        List<loan__loan_account__c> loanAccounts = [SELECT id,name,
                                                           (SELECT id,name,
                                                                   is_active__c,
                                                                   Cancellation_Date__c,
                                                                   Cancellation_Reason__c,
                                                                   Transfer_to__c,
                                                                   Transfer_to__r.is_active__c,
                                                                   Transfer_to__r.Cancellation_daTe__c,
                                                                   Transfer_to__r.Cancellation_Reason__c
                                                             FROM CLS_Selected_Ancillary_Products__r
                                                             WHERE Type__c = 'Credit Optimizer')
                                                    FROM loan__loan_account__c
                                                    WHERE id in: loanIds ];
        List<CLS_Selected_Ancillary_Product__c> toBeUpdatedAncillaryProducts = new List<CLS_Selected_Ancillary_Product__c>();
        for(loan__loan_account__c loanAccount : loanAccounts){
            List<CLS_Selected_Ancillary_Product__c> ancillaryProducts = loanAccount.CLS_Selected_Ancillary_Products__r;
            if(ancillaryProducts != null && ancillaryProducts.size() > 0){
                for(CLS_Selected_Ancillary_Product__c ancillaryProduct : ancillaryProducts){
                     CLS_Selected_Ancillary_Product__c  transferredAncillary = ancillaryProduct.Transfer_to__r;
                     ancillaryProduct.is_active__c = true;
                     ancillaryProduct.Cancellation_date__c = null;
                     ancillaryProduct.Cancellation_Reason__c = null;
                     if(transferredAncillary != null){
                         transferredAncillary.is_active__c = false;
                         transferredAncillary.Cancellation_date__c = new loan.GlobalLoanUtilFacade().getCurrentSystemDate();
                     }
                     toBeUpdatedAncillaryProducts.add(ancillaryProduct);
                     toBeUpdatedAncillaryProducts.add(transferredAncillary);
                 }
             }    
         }    
         SecureDML.updateRecords(toBeUpdatedAncillaryProducts);
    }
}