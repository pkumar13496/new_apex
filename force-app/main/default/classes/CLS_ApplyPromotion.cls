public class CLS_ApplyPromotion {
    /*
* CLS Author Name           : Ajeet Kumar
* Description               : Promotion Validations
* Created / Modified Date   : 15-May-2020
* Jira Id                   : FUS-303
* 
* CLS Author Name           : Govardhana K
* Description               : Repayment Plan should not be created if the Payment Type is Null
* Created / Modified Date   : 25May-2020
* Jira Id                   : FUS-460
*/
    
    public static Promotion_Definition_Details__c promotiondefRecord = new Promotion_Definition_Details__c ();
    public static String applyPromotion(Id applicationId, String promotionType){
        try{
            genesis__Applications__c appRecord = CLS_PromotionUtil.getApplications(applicationId);
            Map<Id,Promotion_Definition_Details__c> qualifiedPromotions = new Map<Id,Promotion_Definition_Details__c>();
            
            List<Promotion_Set__c> applicablePromotions = CLS_PromotionUtil.getAllActivePromotionSets(appRecord,promotionType);
            Map<Id,Promotion_Set__c> qualifiedPromotionSets = new Map<Id,Promotion_Set__c>();
            System.debug('applicablePromotions: ' + applicablePromotions);
            if(!applicablePromotions.isEmpty()){
                
                for(Promotion_Set__c promotionRec :applicablePromotions){
                    System.debug('each Promotion_Set__c: ' + promotionRec);
                    for(Promotion_Definition_Details__c pddRecord :promotionRec.Promotion_Definition_Details__r){
                        System.debug('each Promotion_Definition_Details__c: ' + pddRecord);
                        if(pddRecord.Qualifying_Criteria__c != null){
                            System.debug('pddRecord.Qualifying_Criteria__c:'+pddRecord.Qualifying_Criteria__c);
                            if(CLS_PromotionUtil.evaluateRuleFromClCommonRule(new Set<Id>{applicationId},new Set<Id>{pddRecord.Qualifying_Criteria__c})){
                                qualifiedPromotions.put(pddRecord.Id,pddRecord);
                                qualifiedPromotionSets.put(promotionRec.Id,promotionRec);
                            }
                        }
                    }
                }
            }
            System.debug('qualifiedPromotionSets :' + qualifiedPromotionSets);
            System.debug('qualifiedPromotions definition:' + qualifiedPromotions);
            
            Qualified_Promotions__c[] qualifiedPromotionsList = addQualifiedPromotions(applicationId, qualifiedPromotions.keySet());            
            removeRepaymentAndRateSchedule(applicationId);
            
            // Priority Decision ->No code, Handling by Order by in Query
            if(!qualifiedPromotions.isEmpty()){
                
                Id maxPriorityPromoDef = CLS_PromotionUtil.getHighestPriorityPromotion(qualifiedPromotions.values(),qualifiedPromotionSets);               
                if(maxPriorityPromoDef != null){
                    try{
                        promotiondefRecord = CLS_PromotionUtil.getPromotionDefDetailRecord(maxPriorityPromoDef,appRecord.genesis__Payment_Frequency__c );
                        System.debug('promotiondefRecord: ' + promotiondefRecord);
                        
                        List <clcommon__Repayment_Plan__c> listOfRepaymentPlan =new List<clcommon__Repayment_Plan__c>() ;
                        List<genesis__Rate_Schedule_Setup__c>listOfRateSchedule=new List<genesis__Rate_Schedule_Setup__c>() ;
                        genesis__Applications__c applicationRecord = new genesis__Applications__c(Id=applicationId);
                        
                        
                        if(!String.isEmpty(promotiondefRecord.Amount_Type__c) && promotiondefRecord.Amount_type__c != CLS_CLO_Constants.AMOUNT_TYPE_INTREST_ONLY){
                            listOfRepaymentPlan = createRepaymentPlan(appRecord);
                            listOfRateSchedule=createRateSchedule(appRecord);  
                            applicationRecord.genesis__Interest_Calculation_Method__c = CLS_CLO_Constants.FLEXI_TYPE_INT_CAL_METHOD;
                        }else if(!String.isEmpty(promotiondefRecord.Amount_Type__c) && promotiondefRecord.Amount_type__c == CLS_CLO_Constants.AMOUNT_TYPE_INTREST_ONLY){
                            listOfRateSchedule=createRateSchedule(appRecord);
                            applicationRecord.genesis__Interest_Calculation_Method__c = CLS_CLO_Constants.FLEXI_TYPE_INT_CAL_METHOD;
                        }
                        else{
                            createDefaultRateSchedule(appRecord);
                            applicationRecord.genesis__Interest_Calculation_Method__c = CLS_CLO_Constants.FLEXI_TYPE_INT_CAL_METHOD;
                        }
                        
                        if(maxPriorityPromoDef != null){
                            applicationRecord.Is_Promotion_Applicable__c = true;
                            applicationRecord.Promotion_Definition_Details__c = maxPriorityPromoDef;
                            //applicationRecord.genesis__Status__c = 'PROMOTION APPLIED';
                        }
                        system.debug('applicationRecord.genesis__Interest_Calculation_Method__c='+applicationRecord.genesis__Interest_Calculation_Method__c);
                        system.debug('listOfRateSchedule: ' + listOfRateSchedule);
                        if(listOfRateSchedule.isEmpty() || listOfRateSchedule.size() ==0){
                            System.debug('creating default rate schedule 76');
                            createDefaultRateSchedule(appRecord);  
                        }
                        system.debug('listOfRateSchedule after creating: ' + listOfRateSchedule);
                        
                        if((!listOfRepaymentPlan.isEmpty() && listOfRepaymentPlan.size()>0)||(!listOfRateSchedule.isEmpty() && listOfRateSchedule.size()>0)){
                            applicationRecord.genesis__Interest_Calculation_Method__c = CLS_CLO_Constants.FLEXI_TYPE_INT_CAL_METHOD;
                        }
                        
                        Savepoint sp = Database.setSavepoint();
                        try{
                            System.debug('qualifiedPromotionsList.size() ' + qualifiedPromotionsList.size());
                            if(qualifiedPromotionsList.size() > 0){
                                System.debug('updating prmotions');
                                SecureDML.insertRecords(qualifiedPromotionsList);
                                SecureDML.updateRecords(applicationRecord); 
                                return CLS_CLO_Constants.PROMOTION_SUCCESS;
                            }else{
                                return CLS_CLO_Constants.NO_APPLICABLE_PROMOTIONS;
                            }
                            
                        }catch (DMLException e) {
                            Database.rollback(sp);
                            System.debug('CLS_ApplyPromotion exception: ' + e.getMessage());
                            createDefaultRateSchedule(appRecord);
                            return CLS_CLO_Constants.FAILURE_MESSAGE;
                        } 
                    }catch (Exception e) {
                        System.debug('CLS_ApplyPromotion exception: ' + e.getMessage());
                        createDefaultRateSchedule(appRecord);
                        return CLS_CLO_Constants.FAILURE_MESSAGE;
                    }
                    
                }else{
                    System.debug('Error in fetching maximum promotion definition');
                    createDefaultRateSchedule(appRecord);
                    return CLS_CLO_Constants.NO_APPLICABLE_PROMOTIONS;
                }
                
            }
            else{
                createDefaultRateSchedule(appRecord);
            }
            
            return CLS_CLO_Constants.NO_APPLICABLE_PROMOTIONS;
            
        }catch(Exception ex){
            System.debug('Exception :::'+ex.getMessage() +' AT '+ex.getLineNumber() +' STACKTRACE '+ex.getStackTraceString());
            return CLS_CLO_Constants.FAILURE_MESSAGE;
        }        
    }
    
    public static List<Qualified_Promotions__c> addQualifiedPromotions(Id applicationId, Set<Id> qualifiedPromotionDefList) {
        List<Qualified_Promotions__c> qualifiedPromotionsList = new List<Qualified_Promotions__c>(); 
        Qualified_Promotions__c[] oldqualifiedPromotionsList = [SELECT ID FROM Qualified_Promotions__c WHERE Application__c = :applicationId ];
        if(!oldqualifiedPromotionsList.isEmpty())
        SecureDML.deleteRecords(oldqualifiedPromotionsList);
        
        for(Id promoDefId : qualifiedPromotionDefList){                    
            Qualified_Promotions__c qualifiedPromoDef = new Qualified_Promotions__c();
            qualifiedPromoDef.Promotion_Definition__c = promoDefId;
            qualifiedPromoDef.Application__c = applicationId;
            qualifiedPromotionsList.add(qualifiedPromoDef);
        }             
        System.debug('Qualified_Promotions__c List :' + qualifiedPromotionsList);
        return qualifiedPromotionsList;                
    }
    
    
    public static List<clcommon__Repayment_Plan__c> createRepaymentPlan(genesis__Applications__c appRecord){
        
        List<clcommon__Repayment_Plan__c> repaymentPlanList = new List<clcommon__Repayment_Plan__c>();
        System.debug('promotiondefRecord: ' + promotiondefRecord);
        System.debug('promotiondefRecord.Promotion_Definition_Period_Details__r: ' + promotiondefRecord.Promotion_Definition_Period_Details__r);
        for(Integer i=0;i<1;i++){
            if(promotiondefRecord.Amount_type__c !=NULL){
                clcommon__Repayment_Plan__c repaymentPlan       = new clcommon__Repayment_Plan__c();
                repaymentPlan.genesis__Application__c           = appRecord.Id;
                
                repaymentPlan.clcommon__Due_Day__c              = appRecord.genesis__Due_Day__c;
                if(promotiondefRecord.Promotion_Definition_Period_Details__r.size()>0){
                    repaymentPlan.clcommon__Frequency__c            = promotiondefRecord.Promotion_Definition_Period_Details__r[0].Frequency__c;                
                    repaymentPlan.clcommon__Number_Of_Payments__c   = promotiondefRecord.Promotion_Definition_Period_Details__r[0].Terms__c; 
                }
                
                repaymentPlan.clcommon__Payment_Amount__c       = promotiondefRecord.Amount_type__c != CLS_CLO_Constants.AMOUNT_TYPE_INTREST_ONLY 
                    ? promotiondefRecord.Absolute_Payment_Amount__c : null;
                repaymentPlan.clcommon__Payment_Start_Date__c   =  appRecord.genesis__Expected_First_Payment_Date__c ;                
                repaymentPlan.clcommon__Payment_Type__c         =  promotiondefRecord.Amount_type__c;                
                repaymentPlan.clcommon__Sequence_Number__c      = i+1;  
                repaymentPlan.clcommon__Effective_Date__c = appRecord.genesis__Expected_First_Payment_Date__c ;
                repaymentPlanList.add(repaymentPlan);
            }
        }
        System.debug('repaymentPlanList: ' + repaymentPlanList);
        if(!repaymentPlanList.isEmpty()){
            SecureDML.insertRecords(repaymentPlanList);
        }
        return repaymentPlanList;                
    }
    
    public static void createDefaultRateSchedule(genesis__Applications__c appRecord){
        genesis__Rate_Schedule_Setup__c rateSchedule = new genesis__Rate_Schedule_Setup__c();
        rateSchedule.genesis__Application__c            = appRecord.Id;
        rateSchedule.genesis__Rate_Type__c              = CLS_CLO_Constants.PROMOTION_RATE_TYPE_FIXED;
        rateSchedule.genesis__Sequence__c               = 1;   
        rateSchedule.genesis__Start_Date__c             = appRecord.genesis__Expected_Start_Date__c ; 
        rateSchedule.genesis__Interest_Rate__c          = appRecord.genesis__Interest_Rate__c ;
        rateSchedule.genesis__Terms__c                  =0;
        
        SecureDML.insertRecords(rateSchedule);
        //SecureDML.updateRecords(appRecord);
    }
    
    
    public static List<genesis__Rate_Schedule_Setup__c> createRateSchedule(genesis__Applications__c appRecord){
        
        List<genesis__Rate_Schedule_Setup__c> rateScheduleList = new List<genesis__Rate_Schedule_Setup__c>();
        
        System.debug('appRecord.genesis__Expected_Start_Date__c: ' + appRecord.genesis__Expected_Start_Date__c);
        //Date expectedStartDate = appRecord.genesis__Expected_Start_Date__c;
        Integer dueDay = appRecord.genesis__Expected_Start_Date__c.day();
        Boolean isAppUpdate = false;
        System.debug('dueDay: ' + dueDay);
        
        for(Integer eachRateSch=0; eachRateSch<2;eachRateSch++){
            
            genesis__Rate_Schedule_Setup__c rateSchedule    = new genesis__Rate_Schedule_Setup__c();
            
            rateSchedule.genesis__Application__c            = appRecord.Id;
            rateSchedule.genesis__Rate_Type__c              = CLS_CLO_Constants.PROMOTION_RATE_TYPE_FIXED;
            rateSchedule.genesis__Sequence__c               = eachRateSch+1;                   
            
            if((promotiondefRecord.Absolute_Interest_Rate__c ) || (!promotiondefRecord.Absolute_Interest_Rate__c && (promotiondefRecord.Interest_Rate__c >0)))
            {
                
                
                if(promotiondefRecord.Promotion_Definition_Period_Details__r.size()>0 ){
                    // need Clarification
                    rateSchedule.genesis__Terms__c              = eachRateSch==0 ? promotiondefRecord.Promotion_Definition_Period_Details__r[0].Terms__c :0;
                    
                    System.debug('promotiondefRecord.Promotion_Definition_Period_Details__r:' + promotiondefRecord.Promotion_Definition_Period_Details__r);
                    if (promotiondefRecord.Promotion_Definition_Period_Details__r[0].Terms__c>0){
                        System.debug('appRecord.genesis__Due_Day__c: ' + appRecord.genesis__Due_Day__c);
                        
                        rateSchedule.genesis__Start_Date__c             = eachRateSch==0 ? appRecord.genesis__Expected_Start_Date__c : 
                        genesis.DateUtil.getNextCycleDate(appRecord.genesis__Expected_Start_Date__c
                                                          ,Integer.valueOf(dueDay)
                                                          ,promotiondefRecord.Promotion_Definition_Period_Details__r[0].Frequency__c
                                                          ,Integer.valueOf(promotiondefRecord.Promotion_Definition_Period_Details__r[0].Terms__c));
                        //Date newExpectedStartDate = rateSchedule.genesis__Start_Date__c;
                        
                        rateSchedule.genesis__Interest_Rate__c          = eachRateSch==0  ? (promotiondefRecord.Absolute_Interest_Rate__c 
                                                                                             ? promotiondefRecord.Interest_Rate__c : ((appRecord.genesis__Interest_Rate__c - promotiondefRecord.Interest_Rate__c) <=0 
                                                                                                                                      ? 0 :(appRecord.genesis__Interest_Rate__c - promotiondefRecord.Interest_Rate__c)))
                            : appRecord.genesis__Interest_Rate__c;
                        
                        rateScheduleList.add(rateSchedule);                    
                    }                
                }
                else{
                    
                    rateSchedule.genesis__Start_Date__c = appRecord.genesis__Expected_Start_Date__c ; 
                    rateSchedule.genesis__Interest_Rate__c  = appRecord.genesis__Interest_Rate__c ;
                    rateSchedule.genesis__Terms__c  =0;
                    rateScheduleList.add(rateSchedule);
                    break;
                } 
            }
        }
        
        if(!rateScheduleList.isEmpty()){
            SecureDML.insertRecords(rateScheduleList);
            if(isAppUpdate)
                SecureDML.updateRecords(appRecord);
        }
        
        return rateScheduleList;
        
    }
    
    public static void removeRepaymentAndRateSchedule(String applicationId){
        List<clcommon__Repayment_Plan__c> repaymentPlanList     = new List<clcommon__Repayment_Plan__c>();
        List<genesis__Rate_Schedule_Setup__c> rateScheduleList  = new List<genesis__Rate_Schedule_Setup__c>();
        
        repaymentPlanList   = CLS_PromotionUtil.getRepaymentPlan(applicationId);
        
        rateScheduleList    = CLS_PromotionUtil.getRateSchedule(applicationId);
        
        if(!repaymentPlanList.isEmpty()){
            SecureDML.deleteRecords(repaymentPlanList);
        }
        if(!rateScheduleList.isEmpty()){
            SecureDML.deleteRecords(rateScheduleList);
        }
        
    }    
}