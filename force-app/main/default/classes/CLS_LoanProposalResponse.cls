public class CLS_LoanProposalResponse {
    
    public Decimal PaymentAmt;
    public Decimal PromotionalPaymentAmt;
    public Decimal PaymentOnly;
    public Decimal NumberPayments;
    public Decimal InsPrem;
    public Decimal InsPremPlusTax;
    public Decimal InsTax;
    public Decimal ServiceAmt;
    public Decimal ServiceAmtPlusTax;
    public Decimal ServiceTax;
    public Decimal HomeAutoAmt;
    public Decimal HomeAutoeAmtPlusTax;
    public Decimal HomeAutoTax;
    public Decimal ProcessingFee;
    public Date    Maturity;
    public Decimal GSYAPR;
    public Decimal LoanPlusInt;
    public Decimal TotalCostOfCredit; 
    public Decimal TotalObligation; 
    public Decimal TotalInterestCost;
    public Decimal TotalLPPCost; 
    public Decimal TotalServiceCost;
    public Decimal TotalProcessingFee;
    public Decimal PromoRate;
    public Integer PromoTerm;
    public List<genesis__Amortization_Schedule__c> AmortizationScheduleList;
    public genesis__Lending_Calculator__c Lendingcalcutor;
}