@isTest
public class CLS_ApplyPromotionTest {
    @TestSetup
    static void makeData(){
        Id flowId = JWF_TestHelper.createConsumerunsecuredExecutionFlow().Id;
        clcommon__CL_Product__c product = JWF_TestHelper.createCLProduct('Unsecured Loan',flowId);

        Account acc = TestHelper.createAccount('Test Account');
        Id companyId =  TestHelper.createCompany('Test company').Id;

        genesis__Applications__c application = TestHelper.createApplication(acc,product,companyId);
        
        Promotion_Set__c promotionSet =  CLS_CreateTestData.createPromotionSet('3 Months no EMI', true, 1);
        insert promotionSet;
        
        Promotion_Definition_Details__c proDef = CLS_CreateTestData.createPromotionDefinition('3 Months no EMI','Origination',true,1,null,promotionSet.Id,10,true,0,'',System.today(),System.today().addDays(90));
        insert proDef;
		clcommon__Repayment_Plan__c rePayment = CLS_CreateTestData.createPaymentPlan(application.Id,'Monthly',3);
        genesis__Rate_Schedule_Setup__c rateSchedule = CLS_CreateTestData.createrateSchedule(application.Id,System.today(),10);
        
        insert rePayment;
        insert rateSchedule;
        insert CLS_CreateTestData.createPromotiondefinitionPeriod('Monthly',proDef.Id,3);
        TestHelper.createPricingDetail(application);
    }

    @isTest
    static void testOfferAcceptance(){
        genesis__Applications__c application = [SELECT Id,Is_UPL_PreQual_Passed__c,Is_SPL_PreQual_Passed__c FROM genesis__Applications__c LIMIT 1];
		CLS_ApplyPromotion.applyPromotion(application.Id,'Origination');        
        CLS_ApplyPromotion.removeRepaymentAndRateSchedule(application.Id);
    }
}