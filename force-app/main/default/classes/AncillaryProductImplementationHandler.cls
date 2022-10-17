global class AncillaryProductImplementationHandler {
    public class AncillaryProductException extends Exception {}
    @InvocableMethod
    public static void processAncillaryProduct(List < ID > contractIds) {
//dummy comments
        List < loan__loan_account__c > loanAccList = [Select id, name, RecordTypeId, Active_LPP__c, loan__Periodic_Fee__c, LPP_Prepaid__c, loan__Maturity_Date_Current__c,
            Active_CO__c, Active_H_A__c, Contra_Loan_Account__r.id, loan__Last_Installment_Date__c, loan__First_Installment_Date__c, loan__Account__r.id, loan__Loan_Status__c,
            Lending_Product_Name__c, Contra_Loan_Account__r.loan__Loan_Status__c, loan__Loan_Purpose__r.id, loan__Disbursal_Status__c, loan__Branch__r.id, Contra_Loan_Account__r.Name,
            loan__Next_Installment_Date__c, H_A_Subscription_Amount__c, CO_Subscription_Amount__c, loan__Frequency_of_Loan_Payment__c
            from loan__loan_account__c where id in: contractIds 
        ];
        for (loan__loan_account__c loanAcc: loanAccList) {
            if (loanAcc.loan__Loan_Status__c.contains('Closed - Obligations met')) {
                processClosedObligationsMet(loanAcc);
            } else if (loanAcc.loan__Loan_Status__c.contains('Closed- Written Off')) {
                processClosedWrittenOff(loanAcc);
            } else {
                //call when lending product is not ancillary and loan is disbursed..
                if (!loanAcc.Lending_Product_Name__c.contains('Ancillary Product')) {
                    processLoanProtectionPlan(loanAcc);
                }
                processCreditOptimizer(loanAcc);
                processHomeAndAuto(loanAcc);
            }
        }

    }
    //Method to process LPP Product based on loan__loan_account__c fields..
    public static void processLoanProtectionPlan(loan__loan_account__c loanAcc) {
        if ((!String.isBlank(loanAcc.loan__Disbursal_Status__c) && (loanAcc.loan__Disbursal_Status__c.equals('Partially Disbursed') || loanAcc.loan__Disbursal_Status__c.equals('Fully Disbursed')))) {

            loan__Periodic_Fee_Setup__c periodicFeeSetup = [Select id, name, loan__Fee__r.Name, loan__Fee__r.id, loan__Active__c, LPP_Prepaid__c, loan__Amount__c from loan__Periodic_Fee_Setup__c
                where loan__Lending_Account__r.id =: loanAcc.id and loan__Fee__r.Name like '%Loan Protection Plan%' 
            ];

            //null check..
            if (periodicFeeSetup != null && !loanAcc.Lending_Product_Name__c.contains('Ancillary Product')) {
                if (loanAcc.Active_LPP__c && loanAcc.LPP_Prepaid__c) {
                    //This LPP is Prepaid..

                    //if(!periodicFeeSetup.loan__Active__c ||(periodicFeeSetup.loan__Active__c && loanAcc.loan__Maturity_Date_Current__c == loanAcc.loan__Last_Installment_Date__c)){
                    if (!periodicFeeSetup.loan__Active__c) {
                        //Activate LPP Prepaid, if not active already..
                        periodicFeeSetup.loan__Active__c = true;
                        periodicFeeSetup.loan__Next_Recurring_Fee_Date__c = loanAcc.loan__First_Installment_Date__c;
                        //create a charge..loan__charge__c.. with amount on LPP Periodic Fee Setup..
                        insertChargeAndLPT(periodicFeeSetup.loan__Fee__r.id, loanAcc.id, periodicFeeSetup.loan__Amount__c, false);

                    } else if (loanAcc.loan__Maturity_Date_Current__c != loanAcc.loan__Last_Installment_Date__c) {
                        //Set Fee End Date on Periodic Fee Setup if Current Maturity Date is changed on contract..
                        List<loan__Repayment_Schedule__c> amortizationScheduleList = [SELECT id, name,
                                                                                             loan__Due_Date__c 
                                                                                      FROM loan__Repayment_Schedule__c
                                                                                      WHERE loan__Loan_Account__r.id =: loanAcc.id 
                                                                                      AND loan__Is_Archived__c = false 
                                                                                      ORDER BY loan__Due_Date__c Desc Limit 1 Offset 1
                        ];
                        if(amortizationScheduleList.size()>0){
                            periodicFeeSetup.Fee_End_Date__c = amortizationScheduleList[0].loan__Due_Date__c;
                        }
                    }

                } else if (loanAcc.Active_LPP__c && !loanAcc.LPP_Prepaid__c) {
                    //This LPP is Postpaid..
                    periodicFeeSetup.loan__Active__c = true;

                } else if (!loanAcc.Active_LPP__c) {
                    //This is to deactivate LPP for the CL Contract..
                    periodicFeeSetup.loan__Active__c = false;
                }
                //update periodic Setup fee  lpp..
                try {
                    SecureDML.updateRecords(periodicFeeSetup);
                } catch (Exception e) {
                    system.debug('Exception ---' + e);
                }
            } else {
                //ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Error, 'No Periodic Fee Setup for LPP'));
                //loanAcc.addError('No Periodic Fee Setup for LPP');
                throw new AncillaryProductException('No Periodic Fee Setup for LPP');
            }
        }
    }
    //Method to process Credit Optimizer Product based on loan__loan_account__c fields..
    public static void processCreditOptimizer(loan__loan_account__c loanAcc) {

        //If CO Active done on 'Ancillary Product' loan account..
        if (loanAcc.Lending_Product_Name__c.contains('Ancillary Product')) {
            if (loanAcc.Active_CO__c && loanAcc.Contra_Loan_Account__c != null) {
                //if(!loanAcc.Contra_Loan_Account__r.loan__Loan_Status__c.equals('Closed - Obligations met')){
                //ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Error, 'Activate CO on Primary Account: '+loanAcc.Contra_Loan_Account__r.Name));
                //loanAcc.addError('Activate CO on Primary Account: '+loanAcc.Contra_Loan_Account__r.Name);
                throw new AncillaryProductException('Activate CO on Primary Account: ' + loanAcc.Contra_Loan_Account__r.Name);
                //}
            } else if ((loanAcc.Active_LPP__c || loanAcc.LPP_Prepaid__c) && loanAcc.Contra_Loan_Account__c != null) {
                //ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Error, 'Activate LPP on Primary Account: '+loanAcc.Contra_Loan_Account__r.Name));
                //loanAcc.Active_LPP__c.addError('Activate LPP on Primary Account: '+loanAcc.Contra_Loan_Account__r.Name);
                throw new AncillaryProductException('Activate LPP on Primary Account: ' + loanAcc.Contra_Loan_Account__r.Name);
            } else if ((loanAcc.Active_LPP__c || loanAcc.LPP_Prepaid__c) && loanAcc.Contra_Loan_Account__c == null) {
                //ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Error, 'LPP is not standalone Ancillary Product'));
                //loanAcc.addError('LPP is not standalone Ancillary Product');
                throw new AncillaryProductException('LPP is not standalone Ancillary Product');
            } else if (loanAcc.Active_CO__c && loanAcc.Contra_Loan_Account__c == null) {
                loan__loan_account__c contaLoanAcc = null;
                if (loanAcc.Contra_Loan_Account__c == null) {
                    List < loan__loan_account__c > contaLoanAccList = [Select id, name, Active_CO__c, loan__Disbursal_Status__c, loan__Loan_Status__c, Contra_Loan_Account__r.loan__Loan_Status__c,
                        H_A_Subscription_Amount__c, CO_Subscription_Amount__c from loan__loan_account__c
                        where loan__Account__r.id =: loanAcc.loan__Account__r.id and id !=: loanAcc.id and
                        loan__Loan_Status__c not in ('Closed - Obligations met', 'Closed- Written Off')  limit 1
                    ];
                    if (contaLoanAccList.size() > 0) {
                        contaLoanAcc = contaLoanAccList.get(0);
                    }
                }
                if (contaLoanAcc == null) {
                    if (!String.isBlank(loanAcc.loan__Disbursal_Status__c) && (loanAcc.loan__Disbursal_Status__c.equals('Partially Disbursed') || loanAcc.loan__Disbursal_Status__c.equals('Fully Disbursed'))) {
                        loan__Periodic_Fee_Setup__c periodicFeeSetup = [Select id, name, loan__Fee__r.Name, loan__Fee__r.id, loan__Fee__r.loan__Amount__c, loan__Active__c, loan__Amount__c from loan__Periodic_Fee_Setup__c
                            where loan__Lending_Account__r.id =: loanAcc.id and loan__Fee__r.Name like '%Credit Optimizer%' 
                        ];
                        if (!periodicFeeSetup.loan__Active__c) {
                            periodicFeeSetup.loan__Active__c = true;
                            periodicFeeSetup.loan__Next_Recurring_Fee_Date__c = loanAcc.loan__First_Installment_Date__c;
                            periodicFeeSetup.loan__Amount__c = loanAcc.CO_Subscription_Amount__c;
                            //insert active APS..
                            loan__Payment_Mode__c paymentMode = new loan__Payment_Mode__c();
                            //create LPT to satisfy above created charge..
                            paymentMode = [Select id, name from loan__Payment_Mode__c where Name like '%Cash%'
                                limit 1
                            ];
                            List < loan__Automated_Payment_Setup__c > apsList = [Select id, name, loan__Active__c from loan__Automated_Payment_Setup__c where loan__CL_Contract__r.id =: loanAcc.id ];
                            loan__Automated_Payment_Setup__c aps = null;
                            if (apsList.size() > 0) {
                                aps = apsList.get(0);
                                aps.loan__Active__c = true;
                                aps.loan__Transaction_Amount__c = periodicFeeSetup.loan__Amount__c;
                                SecureDML.updateRecords(aps);
                            }
                            if (aps == null) {

                                insertAPS(loanAcc.Id, periodicFeeSetup.loan__Amount__c, true);

                            }

                            try {
                                SecureDML.updateRecords(periodicFeeSetup);
                                //update aps;
                            } catch (Exception e) {
                                system.debug('Exception ---' + e);
                            }
                        }
                    } else if (((!String.isBlank(loanAcc.loan__Disbursal_Status__c) && loanAcc.loan__Disbursal_Status__c.equals('Pending Disbursal')) || String.isBlank(loanAcc.loan__Disbursal_Status__c))) {
                        if (loanAcc.loan__Loan_Status__c.equals('Approved')) {
                           /* loan__Payment_Mode__c paymentMode = new loan__Payment_Mode__c();
                            paymentMode = [Select id, name from loan__Payment_Mode__c where Name like '%Cash%'
                                limit 1
                            ];
                            //first create disbursal..
                            loan__Loan_Disbursal_Transaction__c ldt = new loan__Loan_Disbursal_Transaction__c();
                            ldt.loan__Loan_Account__c = loanAcc.id;
                            ldt.loan__Financed_Amount__c = 1;
                            ldt.loan__Refinanced_Amount__c = 0;
                            ldt.loan__Disbursed_Amt__c = 1;
                            ldt.loan__Pre_Paid_Fee__c = 0;
                            ldt.loan__Transaction_Creation_Date__c = new loan.GlobalLoanUtilFacade().getCurrentSystemDate();
                            ldt.loan__Mode_of_Payment__c = paymentMode.id;
                            SecureDML.insertRecords(ldt); */
                        }
                    }
                } else {
                    System.debug('contaLoanAcc.Contra_Loan_Account__r.loan__Loan_Status__c: ' + contaLoanAcc);
                    if (!contaLoanAcc.loan__Loan_Status__c.equals('Closed - Obligations met')) {
                        loanAcc.Contra_Loan_Account__c = contaLoanAcc.id;
                        contaLoanAcc.Contra_Loan_Account__c = loanAcc.id;
                        //update loanAcc;
                        //update contaLoanAcc;
                        throw new AncillaryProductException('Activate CO on Primary Account: ' + contaLoanAcc.Name);
                    }
                }
            } else if (!loanAcc.Active_CO__c) {
                List < loan__Periodic_Fee_Setup__c > periodicFeeSetupList = [Select id, name, loan__Fee__r.Name, loan__Fee__r.id, loan__Active__c, loan__Amount__c from loan__Periodic_Fee_Setup__c
                    where loan__Lending_Account__r.id =: loanAcc.id and loan__Fee__r.Name like '%Credit Optimizer%' 
                ];
                loan__Periodic_Fee_Setup__c periodicFeeSetup = null;
                if (periodicFeeSetupList.size() > 0) {
                    periodicFeeSetup = periodicFeeSetupList.get(0);
                }
                if (periodicFeeSetup != null) {
                    periodicFeeSetup.loan__Active__c = false;
                    periodicFeeSetup.loan__Amount__c = loanAcc.CO_Subscription_Amount__c;
                    List < loan__Automated_Payment_Setup__c > apsList = [Select id, name, loan__Active__c from loan__Automated_Payment_Setup__c where loan__CL_Contract__r.id =: loanAcc.id ];
                    loan__Automated_Payment_Setup__c aps = null;
                    if (apsList.size() > 0) {
                        aps = apsList.get(0);
                        aps.loan__Active__c = false;
                        aps.loan__Transaction_Amount__c = periodicFeeSetup.loan__Amount__c;
                        SecureDML.updateRecords(aps);
                    }
                    try {
                        SecureDML.updateRecords(periodicFeeSetup);
                        //update aps;
                    } catch (Exception e) {
                        system.debug('Exception ---' + e);
                    }
                }

            }
        } else if (!loanAcc.Lending_Product_Name__c.contains('Ancillary Product')) {
            if (loanAcc.Active_CO__c && loanAcc.Contra_Loan_Account__c == null) {
                //find contra loan, if not make contra loan..

                List < loan__loan_account__c > contaLoanAccList = [Select id, name, Active_CO__c, loan__Disbursal_Status__c, loan__Loan_Status__c from loan__loan_account__c where Lending_Product_Name__c like '%Ancillary Product%'
                    and
                    loan__Account__r.id =: loanAcc.loan__Account__r.id  limit 1
                ];
                loan__loan_account__c contaLoanAcc = null;
                if (contaLoanAccList.size() > 0) {
                    contaLoanAcc = contaLoanAccList.get(0);
                }
                if (contaLoanAcc == null) {
                    //Making Ancillary Product secondary loan Account..
                    contaLoanAcc = createContraLoanAccount(loanAcc);

                    loan__loan_account__c updatedContraAcc = [Select id, name, Active_CO__c from loan__loan_account__c where Lending_Product_Name__c like '%Ancillary Product%'
                        and
                        id =: contaLoanAcc.id 
                    ];

                    loan__Payment_Mode__c paymentMode = new loan__Payment_Mode__c();
                    paymentMode = [Select id, name from loan__Payment_Mode__c where Name like '%Cash%'
                        limit 1
                    ];
                    //first create disbursal..
                    loan__Loan_Disbursal_Transaction__c ldt = new loan__Loan_Disbursal_Transaction__c();
                    ldt.loan__Loan_Account__c = updatedContraAcc.id;
                    ldt.loan__Financed_Amount__c = 1;
                    ldt.loan__Refinanced_Amount__c = 0;
                    ldt.loan__Disbursed_Amt__c = 1;
                    ldt.loan__Pre_Paid_Fee__c = 0;
                    ldt.loan__Transaction_Creation_Date__c = new loan.GlobalLoanUtilFacade().getCurrentSystemDate();
                    ldt.loan__Mode_of_Payment__c = paymentMode.id;
                    try {
                        SecureDML.insertRecords(ldt);
                    } catch (Exception e) {
                        System.debug('Exception is: ' + e);
                    }
                    loanAcc.Contra_Loan_Account__c = updatedContraAcc.id;
                    //loanAcc.Active_CO__c = true;
                    SecureDML.updateRecords(loanAcc);
                    if (!String.isBlank(loanAcc.loan__Disbursal_Status__c)) {
                        if (loanAcc.loan__Disbursal_Status__c.equals('Partially Disbursed') || loanAcc.loan__Disbursal_Status__c.equals('Fully Disbursed')) {
                            //get periodic fee setup, create charge and lpt..

                            //create charge and lpt..
                            loan__Periodic_Fee_Setup__c periodicFeeSetup = [Select id, name, loan__Fee__r.Name, loan__Fee__r.id, loan__Active__c, loan__Fee__r.loan__Amount__c, loan__Amount__c from loan__Periodic_Fee_Setup__c
                                where loan__Lending_Account__r.id =: loanAcc.id and loan__Fee__r.Name like '%Credit Optimizer%'
                            ];

                            periodicFeeSetup.loan__Active__c = true;
                            periodicFeeSetup.loan__Amount__c = loanAcc.CO_Subscription_Amount__c;
                            periodicFeeSetup.loan__Next_Recurring_Fee_Date__c = loanAcc.loan__First_Installment_Date__c;

                            //insert active APS..
                            //loan__Payment_Mode__c paymentMode = new loan__Payment_Mode__c();
                            //create LPT to satisfy above created charge..
                            //paymentMode = [Select id, name from loan__Payment_Mode__c where Name like '%Cash%' limit 1];
                            List < loan__Automated_Payment_Setup__c > apsList = [Select id, name, loan__Active__c from loan__Automated_Payment_Setup__c where loan__CL_Contract__r.id =: loanAcc.id ];
                            loan__Automated_Payment_Setup__c aps = null;
                            if (apsList.size() > 0) {
                                aps = apsList.get(0);
                                aps.loan__Active__c = true;
                                aps.loan__Transaction_Amount__c = periodicFeeSetup.loan__Amount__c;
                                SecureDML.updateRecords(aps);
                            }
                            if (aps == null) {
                                insertAPS(loanAcc.Id, periodicFeeSetup.loan__Amount__c, true);
                            }
                            try {
                                SecureDML.updateRecords(periodicFeeSetup);
                                //update aps;
                            } catch (Exception e) {
                                system.debug('Exception ---' + e);
                            }
                        }
                    }
                } else if (contaLoanAcc != null && contaLoanAcc.Active_CO__c) {
                    contaLoanAcc.Active_CO__c = false;
                    contaLoanAcc.Active_H_A__c = false;
                    contaLoanAcc.Contra_Loan_Account__c = loanAcc.id;
                    //contaLoanAcc.CO_Subscription_Amount__c = loanAcc.CO_Subscription_Amount__c;
                    //contaLoanAcc.H_A_Subscription_Amount__c = loanAcc.H_A_Subscription_Amount__c;
                    contaLoanAcc.CO_Subscription_Amount__c = 0;
                    contaLoanAcc.H_A_Subscription_Amount__c = 0;
                    loanAcc.Contra_Loan_Account__c = contaLoanAcc.id;
                    loanAcc.Active_CO__c = true;

                    SecureDML.updateRecords(contaLoanAcc);
                    SecureDML.updateRecords(loanAcc);
                    //disable periodic setup on secondary, and deactivate APS..if contra was disbursed..
                    if (!String.isBlank(contaLoanAcc.loan__Disbursal_Status__c) && (contaLoanAcc.loan__Disbursal_Status__c.equals('Partially Disbursed') || contaLoanAcc.loan__Disbursal_Status__c.equals('Fully Disbursed'))) {
                        loan__Periodic_Fee_Setup__c periodicFeeSetup = [Select id, name, loan__Fee__r.Name, loan__Fee__r.id, loan__Active__c, loan__Amount__c from loan__Periodic_Fee_Setup__c
                            where loan__Lending_Account__r.id =: contaLoanAcc.id and loan__Fee__r.Name like '%Credit Optimizer%'
                        ];
                        loan__Periodic_Fee_Setup__c periodicFeeSetupHA = [Select id, name, loan__Fee__r.Name, loan__Fee__r.id, loan__Active__c, loan__Amount__c from loan__Periodic_Fee_Setup__c
                            where loan__Lending_Account__r.id =: contaLoanAcc.id and loan__Fee__r.Name like '%Home And Auto%'
                        ];
                        if (periodicFeeSetup != null) {
                            periodicFeeSetup.loan__Active__c = false;
                            periodicFeeSetup.loan__Amount__c = loanAcc.CO_Subscription_Amount__c;

                            List < loan__Automated_Payment_Setup__c > apsList = [Select id, name, loan__Active__c from loan__Automated_Payment_Setup__c where loan__CL_Contract__r.id =: loanAcc.id ];
                            loan__Automated_Payment_Setup__c aps = null;
                            if (apsList.size() > 0) {
                                aps = apsList.get(0);
                            }
                            if (aps != null) {
                                aps.loan__Active__c = false;
                                aps.loan__Transaction_Amount__c = periodicFeeSetup.loan__Amount__c;
                                SecureDML.updateRecords(aps);
                            }
                            try {
                                SecureDML.updateRecords(periodicFeeSetup);
                            } catch (Exception e) {
                                system.debug('Exception ---' + e);
                            }
                        }
                        if (periodicFeeSetupHA != null) {
                            periodicFeeSetupHA.loan__Active__c = false;
                            periodicFeeSetupHA.loan__Amount__c = loanAcc.CO_Subscription_Amount__c;

                            try {
                                SecureDML.updateRecords(periodicFeeSetupHA);
                            } catch (Exception e) {
                                system.debug('Exception ---' + e);
                            }
                        }
                    } else if ((!String.isBlank(contaLoanAcc.loan__Disbursal_Status__c) && contaLoanAcc.loan__Disbursal_Status__c.equals('Pending Disbursal')) || String.isBlank(contaLoanAcc.loan__Disbursal_Status__c)) {
                        contaLoanAcc.loan__Loan_Status__c = 'Approved';
                        SecureDML.updateRecords(contaLoanAcc);

                        loan__Payment_Mode__c paymentMode = new loan__Payment_Mode__c();
                        paymentMode = [Select id, name from loan__Payment_Mode__c where Name like '%Cash%'
                            limit 1
                        ];
                        //first create disbursal..
                        loan__Loan_Disbursal_Transaction__c ldt = new loan__Loan_Disbursal_Transaction__c();
                        ldt.loan__Loan_Account__c = contaLoanAcc.id;
                        ldt.loan__Financed_Amount__c = 1;
                        ldt.loan__Refinanced_Amount__c = 0;
                        ldt.loan__Disbursed_Amt__c = 1;
                        ldt.loan__Pre_Paid_Fee__c = 0;
                        ldt.loan__Transaction_Creation_Date__c = new loan.GlobalLoanUtilFacade().getCurrentSystemDate();
                        ldt.loan__Mode_of_Payment__c = paymentMode.id;
                        SecureDML.insertRecords(ldt);
                    }
                    if (!String.isBlank(loanAcc.loan__Disbursal_Status__c) && (loanAcc.loan__Disbursal_Status__c.equals('Partially Disbursed') || loanAcc.loan__Disbursal_Status__c.equals('Fully Disbursed'))) {
                        loan__Periodic_Fee_Setup__c periodicFeeSetup = [Select id, name, loan__Fee__r.Name, loan__Fee__r.id, loan__Active__c, loan__Fee__r.loan__Amount__c, loan__Amount__c from loan__Periodic_Fee_Setup__c
                            where loan__Lending_Account__r.id =: loanAcc.id and loan__Fee__r.Name like '%Credit Optimizer%'
                        ];

                        periodicFeeSetup.loan__Active__c = true;
                        periodicFeeSetup.loan__Next_Recurring_Fee_Date__c = loanAcc.loan__First_Installment_Date__c;
                        periodicFeeSetup.loan__Amount__c = loanAcc.CO_Subscription_Amount__c;

                        List < loan__Automated_Payment_Setup__c > apsList = [Select id, name, loan__Active__c from loan__Automated_Payment_Setup__c where loan__CL_Contract__r.id =: loanAcc.id ];
                        loan__Automated_Payment_Setup__c aps = null;
                        if (apsList.size() > 0) {
                            aps = apsList.get(0);
                            aps.loan__Active__c = true;
                            aps.loan__Transaction_Amount__c = periodicFeeSetup.loan__Amount__c;
                            SecureDML.updateRecords(aps);
                        }
                        if (aps == null) {
                            insertAPS(loanAcc.Id, periodicFeeSetup.loan__Amount__c, true);
                        }
                        try {
                            SecureDML.updateRecords(periodicFeeSetup);
                            //update aps;
                        } catch (Exception e) {
                            system.debug('Exception ---' + e);
                        }
                    }
                } else if (contaLoanAcc != null && !contaLoanAcc.Active_CO__c) {
                    contaLoanAcc.Active_CO__c = false;
                    contaLoanAcc.Active_H_A__c = false;
                    contaLoanAcc.Contra_Loan_Account__c = loanAcc.id;
                    //contaLoanAcc.CO_Subscription_Amount__c = loanAcc.CO_Subscription_Amount__c;
                    //contaLoanAcc.H_A_Subscription_Amount__c = loanAcc.H_A_Subscription_Amount__c;
                    contaLoanAcc.CO_Subscription_Amount__c = 0;
                    contaLoanAcc.H_A_Subscription_Amount__c = 0;
                    loanAcc.Contra_Loan_Account__c = contaLoanAcc.id;
                    loanAcc.Active_CO__c = true;

                    SecureDML.updateRecords(contaLoanAcc);
                    SecureDML.updateRecords(loanAcc);

                    if (!String.isBlank(contaLoanAcc.loan__Disbursal_Status__c) && (contaLoanAcc.loan__Disbursal_Status__c.equals('Partially Disbursed') || contaLoanAcc.loan__Disbursal_Status__c.equals('Fully Disbursed'))) {
                        loan__Periodic_Fee_Setup__c periodicFeeSetup = [Select id, name, loan__Fee__r.Name, loan__Fee__r.id, loan__Active__c, loan__Amount__c from loan__Periodic_Fee_Setup__c
                            where loan__Lending_Account__r.id =: contaLoanAcc.id and loan__Fee__r.Name like '%Credit Optimizer%'
                        ];

                        loan__Periodic_Fee_Setup__c periodicFeeSetupHA = [Select id, name, loan__Fee__r.Name, loan__Fee__r.id, loan__Active__c, loan__Amount__c from loan__Periodic_Fee_Setup__c
                            where loan__Lending_Account__r.id =: contaLoanAcc.id and loan__Fee__r.Name like '%Home And Auto%'
                        ];

                        if (periodicFeeSetup != null) {
                            periodicFeeSetup.loan__Active__c = false;
                            periodicFeeSetup.loan__Amount__c = loanAcc.CO_Subscription_Amount__c;

                            List < loan__Automated_Payment_Setup__c > apsList = [Select id, name, loan__Active__c from loan__Automated_Payment_Setup__c where loan__CL_Contract__r.id =: loanAcc.id ];
                            loan__Automated_Payment_Setup__c aps = null;
                            if (apsList.size() > 0) {
                                aps = apsList.get(0);
                            }
                            if (aps != null) {
                                aps.loan__Active__c = false;
                                aps.loan__Transaction_Amount__c = periodicFeeSetup.loan__Amount__c;
                                SecureDML.updateRecords(aps);
                            }
                            try {
                                SecureDML.updateRecords(periodicFeeSetup);
                            } catch (Exception e) {
                                system.debug('Exception ---' + e);
                            }
                        }
                        if (periodicFeeSetupHA != null) {
                            periodicFeeSetupHA.loan__Active__c = false;
                            periodicFeeSetupHA.loan__Amount__c = loanAcc.H_A_Subscription_Amount__c;
                            try {
                                SecureDML.updateRecords(periodicFeeSetupHA);
                            } catch (Exception e) {
                                system.debug('Exception ---' + e);
                            }
                        }
                    } else if ((!String.isBlank(contaLoanAcc.loan__Disbursal_Status__c) && contaLoanAcc.loan__Disbursal_Status__c.equals('Pending Disbursal')) || String.isBlank(contaLoanAcc.loan__Disbursal_Status__c)) {
                        contaLoanAcc.loan__Loan_Status__c = 'Approved';
                        contaLoanAcc.Contra_Loan_Account__c = loanAcc.id;
                        SecureDML.updateRecords(contaLoanAcc);

                        loan__Payment_Mode__c paymentMode = new loan__Payment_Mode__c();
                        paymentMode = [Select id, name from loan__Payment_Mode__c where Name like '%Cash%'
                            limit 1
                        ];
                        //first create disbursal..
                        loan__Loan_Disbursal_Transaction__c ldt = new loan__Loan_Disbursal_Transaction__c();
                        ldt.loan__Loan_Account__c = contaLoanAcc.id;
                        ldt.loan__Financed_Amount__c = 1;
                        ldt.loan__Refinanced_Amount__c = 0;
                        ldt.loan__Disbursed_Amt__c = 1;
                        ldt.loan__Pre_Paid_Fee__c = 0;
                        ldt.loan__Transaction_Creation_Date__c = new loan.GlobalLoanUtilFacade().getCurrentSystemDate();
                        ldt.loan__Mode_of_Payment__c = paymentMode.id;
                        SecureDML.insertRecords(ldt);
                    }
                    if (!String.isBlank(loanAcc.loan__Disbursal_Status__c) && (loanAcc.loan__Disbursal_Status__c.equals('Partially Disbursed') || loanAcc.loan__Disbursal_Status__c.equals('Fully Disbursed'))) {
                        loan__Periodic_Fee_Setup__c periodicFeeSetup = [Select id, name, loan__Fee__r.Name, loan__Fee__r.id, loan__Active__c, loan__Fee__r.loan__Amount__c, loan__Amount__c from loan__Periodic_Fee_Setup__c
                            where loan__Lending_Account__r.id =: loanAcc.id and loan__Fee__r.Name like '%Credit Optimizer%'
                        ];

                        periodicFeeSetup.loan__Active__c = true;
                        periodicFeeSetup.loan__Amount__c = loanAcc.CO_Subscription_Amount__c;
                        periodicFeeSetup.loan__Next_Recurring_Fee_Date__c = loanAcc.loan__First_Installment_Date__c;
                        List < loan__Automated_Payment_Setup__c > apsList = [Select id, name, loan__Active__c from loan__Automated_Payment_Setup__c where loan__CL_Contract__r.id =: loanAcc.id ];
                        loan__Automated_Payment_Setup__c aps = null;
                        if (apsList.size() > 0) {
                            aps = apsList.get(0);
                            aps.loan__Active__c = true;
                            aps.loan__Transaction_Amount__c = periodicFeeSetup.loan__Amount__c;
                            SecureDML.updateRecords(aps);
                        }
                        if (aps == null) {
                            insertAPS(loanAcc.Id, periodicFeeSetup.loan__Amount__c, true);
                        }
                        try {
                            SecureDML.updateRecords(periodicFeeSetup);
                            //update aps;
                        } catch (Exception e) {
                            system.debug('Exception ---' + e);
                        }
                    }
                }
            } else if (loanAcc.Active_CO__c && loanAcc.Contra_Loan_Account__c != null &&
                (!String.isBlank(loanAcc.loan__Disbursal_Status__c) && (loanAcc.loan__Disbursal_Status__c.equals('Partially Disbursed') || loanAcc.loan__Disbursal_Status__c.equals('Fully Disbursed')))) {
                loanAcc.Active_CO__c = true;

                loan__Periodic_Fee_Setup__c periodicFeeSetup = [Select id, name, loan__Fee__r.Name, loan__Fee__r.id, loan__Active__c, loan__Fee__r.loan__Amount__c, loan__Amount__c from loan__Periodic_Fee_Setup__c
                    where loan__Lending_Account__r.id =: loanAcc.id and loan__Fee__r.Name like '%Credit Optimizer%' 
                ];
                if (!periodicFeeSetup.loan__Active__c) {
                    periodicFeeSetup.loan__Active__c = true;
                    periodicFeeSetup.loan__Next_Recurring_Fee_Date__c = loanAcc.loan__First_Installment_Date__c;
                    periodicFeeSetup.loan__Amount__c = loanAcc.CO_Subscription_Amount__c;

                    List < loan__Automated_Payment_Setup__c > apsList = [Select id, name, loan__Active__c from loan__Automated_Payment_Setup__c where loan__CL_Contract__r.id =: loanAcc.id ];
                    loan__Automated_Payment_Setup__c aps = null;
                    if (apsList.size() > 0) {
                        aps = apsList.get(0);
                        aps.loan__Active__c = true;
                        aps.loan__Transaction_Amount__c = periodicFeeSetup.loan__Amount__c;
                        SecureDML.updateRecords(aps);
                    }
                    if (aps == null) {
                        insertAPS(loanAcc.Id, periodicFeeSetup.loan__Amount__c, true);
                    }

                    try {
                        SecureDML.updateRecords(periodicFeeSetup);
                        //update aps;
                    } catch (Exception e) {
                        system.debug('Exception ---' + e);
                    }
                }
            } else if (!loanAcc.Active_CO__c &&
                (!String.isBlank(loanAcc.loan__Disbursal_Status__c) && (loanAcc.loan__Disbursal_Status__c.equals('Partially Disbursed') || loanAcc.loan__Disbursal_Status__c.equals('Fully Disbursed')))) {

                loan__Periodic_Fee_Setup__c periodicFeeSetup = [Select id, name, loan__Fee__r.Name, loan__Fee__r.id, loan__Active__c, loan__Amount__c from loan__Periodic_Fee_Setup__c
                    where loan__Lending_Account__r.id =: loanAcc.id and loan__Fee__r.Name like '%Credit Optimizer%'
                ];
                if (periodicFeeSetup != null) {
                    periodicFeeSetup.loan__Active__c = false;
                    periodicFeeSetup.loan__Amount__c = loanAcc.CO_Subscription_Amount__c;

                    List < loan__Automated_Payment_Setup__c > apsList = [Select id, name, loan__Active__c from loan__Automated_Payment_Setup__c where loan__CL_Contract__r.id =: loanAcc.id ];
                    loan__Automated_Payment_Setup__c aps = null;
                    if (apsList.size() > 0) {
                        aps = apsList.get(0);
                    }
                    if (aps != null) {
                        aps.loan__Active__c = false;
                        aps.loan__Transaction_Amount__c = periodicFeeSetup.loan__Amount__c;
                        SecureDML.updateRecords(aps);
                    }
                    try {
                        SecureDML.updateRecords(periodicFeeSetup);
                    } catch (Exception e) {
                        system.debug('Exception ---' + e);
                    }
                }
            }
        }
    }
    public static void processHomeAndAuto(loan__loan_account__c loanAcc) { //If CO Active done on 'Ancillary Product' loan account..
        if (loanAcc.Lending_Product_Name__c.contains('Ancillary Product')) {
            if (loanAcc.Active_H_A__c && loanAcc.Contra_Loan_Account__c != null) {
                //ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Error, 'Activate CO on Primary Account: '+loanAcc.Contra_Loan_Account__r.Name));
                //loanAcc.addError('Activate CO on Primary Account: '+loanAcc.Contra_Loan_Account__r.Name);
                throw new AncillaryProductException('Activate H&A on Primary Account: ' + loanAcc.Contra_Loan_Account__r.Name);
            } else if ((loanAcc.Active_LPP__c || loanAcc.LPP_Prepaid__c) && loanAcc.Contra_Loan_Account__c != null) {
                //ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Error, 'Activate LPP on Primary Account: '+loanAcc.Contra_Loan_Account__r.Name));
                //loanAcc.Active_LPP__c.addError('Activate LPP on Primary Account: '+loanAcc.Contra_Loan_Account__r.Name);
                throw new AncillaryProductException('Activate LPP on Primary Account: ' + loanAcc.Contra_Loan_Account__r.Name);
            } else if ((loanAcc.Active_LPP__c || loanAcc.LPP_Prepaid__c) && loanAcc.Contra_Loan_Account__c == null) {
                //ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Error, 'LPP is not standalone Ancillary Product'));
                //loanAcc.addError('LPP is not standalone Ancillary Product');
                throw new AncillaryProductException('LPP is not standalone Ancillary Product');
            } else if (loanAcc.Active_H_A__c && loanAcc.Contra_Loan_Account__c == null) {
                loan__loan_account__c contaLoanAcc = null;
                if (loanAcc.Contra_Loan_Account__c == null) {
                    List < loan__loan_account__c > contaLoanAccList = [Select id, name, Active_H_A__c, loan__Disbursal_Status__c, loan__Loan_Status__c from loan__loan_account__c
                        where loan__Account__r.id =: loanAcc.loan__Account__r.id and id !=: loanAcc.id and
                        loan__Loan_Status__c not in ('Closed - Obligations met', 'Closed- Written Off')  limit 1
                    ];
                    if (contaLoanAccList.size() > 0) {
                        contaLoanAcc = contaLoanAccList.get(0);
                    }
                }
                if (contaLoanAcc == null) {
                    if (!String.isBlank(loanAcc.loan__Disbursal_Status__c) && (loanAcc.loan__Disbursal_Status__c.equals('Partially Disbursed') || loanAcc.loan__Disbursal_Status__c.equals('Fully Disbursed'))) {
                        loan__Periodic_Fee_Setup__c periodicFeeSetup = [Select id, name, loan__Fee__r.Name, loan__Fee__r.id, loan__Fee__r.loan__Amount__c, loan__Active__c, loan__Amount__c from loan__Periodic_Fee_Setup__c
                            where loan__Lending_Account__r.id =: loanAcc.id and loan__Fee__r.Name like '%Home And Auto%' 
                        ];
                        if (!periodicFeeSetup.loan__Active__c) {
                            //Activate H&A, if not active already..
                            periodicFeeSetup.loan__Active__c = true;
                            //periodicFeeSetup.loan__Next_Recurring_Fee_Date__c = loanAcc.loan__First_Installment_Date__c;
                            periodicFeeSetup.loan__Next_Recurring_Fee_Date__c = Date.newInstance(3000, 12, 31);
                            periodicFeeSetup.loan__Amount__c = loanAcc.H_A_Subscription_Amount__c;
                            
                            //create a charge..loan__charge__c.. with amount on LPP Periodic Fee Setup..
                            insertChargeAndLPT(periodicFeeSetup.loan__Fee__r.id, loanAcc.id, periodicFeeSetup.loan__Amount__c, false);

                            SecureDML.updateRecords(periodicFeeSetup);
                        }
                    } else if (((!String.isBlank(loanAcc.loan__Disbursal_Status__c) && loanAcc.loan__Disbursal_Status__c.equals('Pending Disbursal')) || String.isBlank(loanAcc.loan__Disbursal_Status__c))) {
                        if (loanAcc.loan__Loan_Status__c.equals('Approved')) {
                           /* loan__Payment_Mode__c paymentMode = new loan__Payment_Mode__c();
                            paymentMode = [Select id, name from loan__Payment_Mode__c where Name like '%Cash%'
                                limit 1
                            ];
                            //first create disbursal..
                            loan__Loan_Disbursal_Transaction__c ldt = new loan__Loan_Disbursal_Transaction__c();
                            ldt.loan__Loan_Account__c = loanAcc.id;
                            ldt.loan__Financed_Amount__c = 1;
                            ldt.loan__Refinanced_Amount__c = 0;
                            ldt.loan__Disbursed_Amt__c = 1;
                            ldt.loan__Pre_Paid_Fee__c = 0;
                            ldt.loan__Transaction_Creation_Date__c = new loan.GlobalLoanUtilFacade().getCurrentSystemDate();
                            ldt.loan__Mode_of_Payment__c = paymentMode.id;
                            try {
                                SecureDML.insertRecords(ldt);
                            } catch (Exception e) {

                            } */
                        }
                    }
                } else {
                    if (!contaLoanAcc.loan__Loan_Status__c.equals('Closed - Obligations met')) {
                        loanAcc.Contra_Loan_Account__c = contaLoanAcc.id;
                        contaLoanAcc.Contra_Loan_Account__c = loanAcc.id;
                        //update loanAcc;
                        //update contaLoanAcc;
                        throw new AncillaryProductException('Activate H&A on Primary Account: ' + contaLoanAcc.Name);
                    }
                }
            } else if (!loanAcc.Active_H_A__c) {
                List < loan__Periodic_Fee_Setup__c > periodicFeeSetupList = [Select id, name, loan__Fee__r.Name, loan__Fee__r.id, loan__Active__c, loan__Amount__c from loan__Periodic_Fee_Setup__c
                    where loan__Lending_Account__r.id =: loanAcc.id and loan__Fee__r.Name like '%Home And Auto%' 
                ];
                loan__Periodic_Fee_Setup__c periodicFeeSetup = null;
                if (periodicFeeSetupList.size() > 0) {
                    periodicFeeSetup = periodicFeeSetupList.get(0);
                }
                if (periodicFeeSetup != null) {
                    periodicFeeSetup.loan__Active__c = false;
                    periodicFeeSetup.loan__Amount__c = loanAcc.H_A_Subscription_Amount__c;
                    try {
                        SecureDML.updateRecords(periodicFeeSetup);
                        //update aps;
                    } catch (Exception e) {
                        system.debug('Exception ---' + e);
                    }
                }

            }
        } else if (!loanAcc.Lending_Product_Name__c.contains('Ancillary Product')) {
            if (loanAcc.Active_H_A__c && loanAcc.Contra_Loan_Account__c == null) {
                //find contra loan, if not make contra loan..

                List < loan__loan_account__c > contaLoanAccList = [Select id, name, Active_H_A__c, loan__Disbursal_Status__c, loan__Loan_Status__c from loan__loan_account__c where Lending_Product_Name__c like '%Ancillary Product%'
                    and
                    loan__Account__r.id =: loanAcc.loan__Account__r.id  limit 1
                ];
                loan__loan_account__c contaLoanAcc = null;
                if (contaLoanAccList.size() > 0) {
                    contaLoanAcc = contaLoanAccList.get(0);
                }
                if (contaLoanAcc == null) {
                    //Making Ancillary Product secondary loan Account..
                    //Making Ancillary Product secondary loan Account..
                    contaLoanAcc = createContraLoanAccount(loanAcc);

                    loan__loan_account__c updatedContraAcc = [Select id, name, Active_CO__c from loan__loan_account__c where Lending_Product_Name__c like '%Ancillary Product%'
                        and
                        id =: contaLoanAcc.id 
                    ];

                    loan__Payment_Mode__c paymentMode = new loan__Payment_Mode__c();
                    paymentMode = [Select id, name from loan__Payment_Mode__c where Name like '%Cash%'
                        limit 1
                    ];
                    //first create disbursal..
                    loan__Loan_Disbursal_Transaction__c ldt = new loan__Loan_Disbursal_Transaction__c();
                    ldt.loan__Loan_Account__c = updatedContraAcc.id;
                    ldt.loan__Financed_Amount__c = 1;
                    ldt.loan__Refinanced_Amount__c = 0;
                    ldt.loan__Disbursed_Amt__c = 1;
                    ldt.loan__Pre_Paid_Fee__c = 0;
                    ldt.loan__Transaction_Creation_Date__c = new loan.GlobalLoanUtilFacade().getCurrentSystemDate();
                    ldt.loan__Mode_of_Payment__c = paymentMode.id;
                    try {
                        SecureDML.insertRecords(ldt);
                    } catch (Exception e) {
                        System.debug('Exception is: ' + e);
                    }
                    loanAcc.Contra_Loan_Account__c = updatedContraAcc.id;
                    //loanAcc.Active_H_A__c = true;
                    SecureDML.updateRecords(loanAcc);
                    if (!String.isBlank(loanAcc.loan__Disbursal_Status__c)) {
                        if (loanAcc.loan__Disbursal_Status__c.equals('Partially Disbursed') || loanAcc.loan__Disbursal_Status__c.equals('Fully Disbursed')) {
                            //get periodic fee setup, create charge and lpt..

                            //create charge and lpt..
                            loan__Periodic_Fee_Setup__c periodicFeeSetup = [Select id, name, loan__Fee__r.Name, loan__Fee__r.id, loan__Active__c, loan__Fee__r.loan__Amount__c, loan__Amount__c from loan__Periodic_Fee_Setup__c
                                where loan__Lending_Account__r.id =: loanAcc.id and loan__Fee__r.Name like '%Home And Auto%' 
                            ];

                            if (!periodicFeeSetup.loan__Active__c) {
                                //Activate H&A, if not active already..
                                periodicFeeSetup.loan__Active__c = true;
                                //periodicFeeSetup.loan__Next_Recurring_Fee_Date__c = loanAcc.loan__First_Installment_Date__c;
                                periodicFeeSetup.loan__Next_Recurring_Fee_Date__c = Date.newInstance(3000, 12, 31);
                                periodicFeeSetup.loan__Amount__c = loanAcc.H_A_Subscription_Amount__c;
                                
                                //create a charge..loan__charge__c.. with amount on LPP Periodic Fee Setup..
                                insertChargeAndLPT(periodicFeeSetup.loan__Fee__r.id, loanAcc.id, periodicFeeSetup.loan__Amount__c, false);
                            }
                            try {
                                SecureDML.updateRecords(periodicFeeSetup);
                                //update aps;
                            } catch (Exception e) {
                                system.debug('Exception ---' + e);
                            }
                        }
                    }
                } else if (contaLoanAcc != null && contaLoanAcc.Active_H_A__c) {
                    contaLoanAcc.Active_H_A__c = false;
                    contaLoanAcc.Active_CO__c = false;
                    //contaLoanAcc.CO_Subscription_Amount__c = loanAcc.CO_Subscription_Amount__c;
                    //contaLoanAcc.H_A_Subscription_Amount__c = loanAcc.H_A_Subscription_Amount__c;
                    contaLoanAcc.CO_Subscription_Amount__c = 0;
                    contaLoanAcc.H_A_Subscription_Amount__c = 0;
                    contaLoanAcc.Contra_Loan_Account__c = loanAcc.id;

                    loanAcc.Contra_Loan_Account__c = contaLoanAcc.id;
                    loanAcc.Active_H_A__c = true;

                    SecureDML.updateRecords(contaLoanAcc);
                    SecureDML.updateRecords(loanAcc);
                    //disable periodic setup on secondary, and deactivate APS..if contra was disbursed..
                    if (!String.isBlank(contaLoanAcc.loan__Disbursal_Status__c) && (contaLoanAcc.loan__Disbursal_Status__c.equals('Partially Disbursed') || contaLoanAcc.loan__Disbursal_Status__c.equals('Fully Disbursed'))) {
                        loan__Periodic_Fee_Setup__c periodicFeeSetup = [Select id, name, loan__Fee__r.Name, loan__Fee__r.id, loan__Active__c, loan__Amount__c from loan__Periodic_Fee_Setup__c
                            where loan__Lending_Account__r.id =: contaLoanAcc.id and loan__Fee__r.Name like '%Home And Auto%'
                        ];
                        loan__Periodic_Fee_Setup__c periodicFeeSetupCO = [Select id, name, loan__Fee__r.Name, loan__Fee__r.id, loan__Active__c, loan__Amount__c from loan__Periodic_Fee_Setup__c
                            where loan__Lending_Account__r.id =: contaLoanAcc.id and loan__Fee__r.Name like '%Credit Optimizer%'
                        ];
                        if (periodicFeeSetup != null) {
                            periodicFeeSetup.loan__Active__c = false;
                            periodicFeeSetup.loan__Amount__c = loanAcc.CO_Subscription_Amount__c;

                            try {
                                SecureDML.updateRecords(periodicFeeSetup);
                            } catch (Exception e) {
                                system.debug('Exception ---' + e);
                            }
                        }
                        if (periodicFeeSetupCO != null) {
                            periodicFeeSetup.loan__Active__c = false;
                            periodicFeeSetupCO.loan__Amount__c = loanAcc.H_A_Subscription_Amount__c;

                            List < loan__Automated_Payment_Setup__c > apsList = [Select id, name, loan__Active__c from loan__Automated_Payment_Setup__c where loan__CL_Contract__r.id =: loanAcc.id ];
                            loan__Automated_Payment_Setup__c aps = null;
                            if (apsList.size() > 0) {
                                aps = apsList.get(0);
                                aps.loan__Active__c = false;
                                aps.loan__Transaction_Amount__c = periodicFeeSetupCO.loan__Amount__c;
                                SecureDML.updateRecords(aps);
                            }
                            try {
                                SecureDML.updateRecords(periodicFeeSetupCO);
                            } catch (Exception e) {
                                system.debug('Exception ---' + e);
                            }
                        }
                    } else if ((!String.isBlank(contaLoanAcc.loan__Disbursal_Status__c) && contaLoanAcc.loan__Disbursal_Status__c.equals('Pending Disbursal')) || String.isBlank(contaLoanAcc.loan__Disbursal_Status__c)) {
                        contaLoanAcc.loan__Loan_Status__c = 'Approved';
                        SecureDML.updateRecords(contaLoanAcc);

                        loan__Payment_Mode__c paymentMode = new loan__Payment_Mode__c();
                        paymentMode = [Select id, name from loan__Payment_Mode__c where Name like '%Cash%'
                            limit 1
                        ];
                        //first create disbursal..
                        loan__Loan_Disbursal_Transaction__c ldt = new loan__Loan_Disbursal_Transaction__c();
                        ldt.loan__Loan_Account__c = contaLoanAcc.id;
                        ldt.loan__Financed_Amount__c = 1;
                        ldt.loan__Refinanced_Amount__c = 0;
                        ldt.loan__Disbursed_Amt__c = 1;
                        ldt.loan__Pre_Paid_Fee__c = 0;
                        ldt.loan__Transaction_Creation_Date__c = new loan.GlobalLoanUtilFacade().getCurrentSystemDate();
                        ldt.loan__Mode_of_Payment__c = paymentMode.id;
                        try {
                            SecureDML.insertRecords(ldt);
                        } catch (Exception e) {

                        }
                    }
                    if (!String.isBlank(loanAcc.loan__Disbursal_Status__c) && (loanAcc.loan__Disbursal_Status__c.equals('Partially Disbursed') || loanAcc.loan__Disbursal_Status__c.equals('Fully Disbursed'))) {
                        loan__Periodic_Fee_Setup__c periodicFeeSetup = [Select id, name, loan__Fee__r.Name, loan__Fee__r.id, loan__Active__c, loan__Fee__r.loan__Amount__c, loan__Amount__c from loan__Periodic_Fee_Setup__c
                            where loan__Lending_Account__r.id =: loanAcc.id and loan__Fee__r.Name like '%Home And Auto%' 
                        ];

                        if (!periodicFeeSetup.loan__Active__c) {
                            //Activate H&A, if not active already..
                            periodicFeeSetup.loan__Active__c = true;
                            //periodicFeeSetup.loan__Next_Recurring_Fee_Date__c = loanAcc.loan__First_Installment_Date__c;
                            periodicFeeSetup.loan__Next_Recurring_Fee_Date__c = Date.newInstance(3000, 12, 31);
                            periodicFeeSetup.loan__Amount__c = loanAcc.H_A_Subscription_Amount__c;

                            //create a charge..loan__charge__c.. with amount on LPP Periodic Fee Setup..
                            insertChargeAndLPT(periodicFeeSetup.loan__Fee__r.id, loanAcc.id, periodicFeeSetup.loan__Amount__c, false);
                        }
                        try {
                            SecureDML.updateRecords(periodicFeeSetup);
                            //update aps;
                        } catch (Exception e) {
                            system.debug('Exception ---' + e);
                        }
                        // }
                        // }
                    }
                } else if (contaLoanAcc != null && !contaLoanAcc.Active_H_A__c && !loanAcc.loan__Loan_Status__c.equals('Closed - Obligations met')) {
                    contaLoanAcc.Active_H_A__c = false;
                    contaLoanAcc.Active_CO__c = false;
                    //contaLoanAcc.CO_Subscription_Amount__c = loanAcc.CO_Subscription_Amount__c;
                    //contaLoanAcc.H_A_Subscription_Amount__c = loanAcc.H_A_Subscription_Amount__c;
                    contaLoanAcc.CO_Subscription_Amount__c = 0;
                    contaLoanAcc.H_A_Subscription_Amount__c = 0;
                    contaLoanAcc.Contra_Loan_Account__c = loanAcc.id;

                    loanAcc.Contra_Loan_Account__c = contaLoanAcc.id;
                    //loanAcc.Active_H_A__c = true;

                    SecureDML.updateRecords(contaLoanAcc);
                    SecureDML.updateRecords(loanAcc);

                    if (!String.isBlank(contaLoanAcc.loan__Disbursal_Status__c) && (contaLoanAcc.loan__Disbursal_Status__c.equals('Partially Disbursed') || contaLoanAcc.loan__Disbursal_Status__c.equals('Fully Disbursed'))) {
                        loan__Periodic_Fee_Setup__c periodicFeeSetup = [Select id, name, loan__Fee__r.Name, loan__Fee__r.id, loan__Active__c, loan__Amount__c from loan__Periodic_Fee_Setup__c
                            where loan__Lending_Account__r.id =: contaLoanAcc.id and loan__Fee__r.Name like '%Home And Auto%'
                        ];
                        loan__Periodic_Fee_Setup__c periodicFeeSetupCO = [Select id, name, loan__Fee__r.Name, loan__Fee__r.id, loan__Active__c, loan__Amount__c from loan__Periodic_Fee_Setup__c
                            where loan__Lending_Account__r.id =: contaLoanAcc.id and loan__Fee__r.Name like '%Credit Optimizer%'
                        ];

                        if (periodicFeeSetup != null) {
                            periodicFeeSetup.loan__Active__c = false;
                            periodicFeeSetup.loan__Amount__c = loanAcc.H_A_Subscription_Amount__c;

                            try {
                                SecureDML.updateRecords(periodicFeeSetup);
                            } catch (Exception e) {
                                system.debug('Exception ---' + e);
                            }
                        }
                        if (periodicFeeSetupCO != null) {
                            periodicFeeSetupCO.loan__Active__c = false;
                            periodicFeeSetupCO.loan__Amount__c = loanAcc.CO_Subscription_Amount__c;

                            List < loan__Automated_Payment_Setup__c > apsList = [Select id, name, loan__Active__c from loan__Automated_Payment_Setup__c where loan__CL_Contract__r.id =: loanAcc.id ];
                            loan__Automated_Payment_Setup__c aps = null;
                            if (apsList.size() > 0) {
                                aps = apsList.get(0);
                                aps.loan__Active__c = false;
                                aps.loan__Transaction_Amount__c = periodicFeeSetupCO.loan__Amount__c;
                                System.debug('!contaLoanAcc.loan__Loan_Status__c1067: ' + contaLoanAcc.loan__Loan_Status__c);
                                SecureDML.updateRecords(aps);
                            }
                            try {
                                SecureDML.updateRecords(periodicFeeSetupCO);
                            } catch (Exception e) {
                                system.debug('Exception ---' + e);
                            }
                        }

                    } else if ((!String.isBlank(contaLoanAcc.loan__Disbursal_Status__c) && contaLoanAcc.loan__Disbursal_Status__c.equals('Pending Disbursal')) || String.isBlank(contaLoanAcc.loan__Disbursal_Status__c)) {
                        contaLoanAcc.loan__Loan_Status__c = 'Approved';
                        contaLoanAcc.Contra_Loan_Account__c = loanAcc.id;
                        SecureDML.updateRecords(contaLoanAcc);

                        loan__Payment_Mode__c paymentMode = new loan__Payment_Mode__c();
                        paymentMode = [Select id, name from loan__Payment_Mode__c where Name like '%Cash%'
                            limit 1
                        ];
                        //first create disbursal..
                        loan__Loan_Disbursal_Transaction__c ldt = new loan__Loan_Disbursal_Transaction__c();
                        ldt.loan__Loan_Account__c = contaLoanAcc.id;
                        ldt.loan__Financed_Amount__c = 1;
                        ldt.loan__Refinanced_Amount__c = 0;
                        ldt.loan__Disbursed_Amt__c = 1;
                        ldt.loan__Pre_Paid_Fee__c = 0;
                        ldt.loan__Transaction_Creation_Date__c = new loan.GlobalLoanUtilFacade().getCurrentSystemDate();
                        ldt.loan__Mode_of_Payment__c = paymentMode.id;
                        try {
                            SecureDML.insertRecords(ldt);
                        } catch (Exception e) {

                        }
                    }
                    if (!String.isBlank(loanAcc.loan__Disbursal_Status__c) && (loanAcc.loan__Disbursal_Status__c.equals('Partially Disbursed') || loanAcc.loan__Disbursal_Status__c.equals('Fully Disbursed'))) {
                        loan__Periodic_Fee_Setup__c periodicFeeSetup = [Select id, name, loan__Fee__r.Name, loan__Fee__r.id, loan__Active__c, loan__Fee__r.loan__Amount__c, loan__Amount__c from loan__Periodic_Fee_Setup__c
                            where loan__Lending_Account__r.id =: loanAcc.id and loan__Fee__r.Name like '%Home And Auto%' 
                        ];

                        if (!periodicFeeSetup.loan__Active__c) {
                            //Activate H&A, if not active already..
                            periodicFeeSetup.loan__Active__c = true;
                            //periodicFeeSetup.loan__Next_Recurring_Fee_Date__c = loanAcc.loan__First_Installment_Date__c;
                            periodicFeeSetup.loan__Next_Recurring_Fee_Date__c = Date.newInstance(3000, 12, 31);
                            periodicFeeSetup.loan__Amount__c = loanAcc.H_A_Subscription_Amount__c;

                            //create a charge..loan__charge__c.. with amount on LPP Periodic Fee Setup..
                            insertChargeAndLPT(periodicFeeSetup.loan__Fee__r.id, loanAcc.id, periodicFeeSetup.loan__Amount__c, false);
                        }
                        try {
                            SecureDML.updateRecords(periodicFeeSetup);
                            //update aps;
                        } catch (Exception e) {
                            system.debug('Exception ---' + e);
                        }
                    }
                }
            } else if (loanAcc.Active_H_A__c && loanAcc.Contra_Loan_Account__c != null &&
                (!String.isBlank(loanAcc.loan__Disbursal_Status__c) && (loanAcc.loan__Disbursal_Status__c.equals('Partially Disbursed') || loanAcc.loan__Disbursal_Status__c.equals('Fully Disbursed')))) {
                loanAcc.Active_H_A__c = true;

                loan__Periodic_Fee_Setup__c periodicFeeSetup = [Select id, name, loan__Fee__r.Name, loan__Fee__r.id, loan__Active__c, loan__Fee__r.loan__Amount__c, loan__Amount__c from loan__Periodic_Fee_Setup__c
                    where loan__Lending_Account__r.id =: loanAcc.id and loan__Fee__r.Name like '%Home And Auto%' 
                ];
                if (!periodicFeeSetup.loan__Active__c) {
                    //Activate H&A, if not active already..
                    periodicFeeSetup.loan__Active__c = true;
                    periodicFeeSetup.loan__Amount__c = loanAcc.H_A_Subscription_Amount__c;
                    //periodicFeeSetup.loan__Next_Recurring_Fee_Date__c = loanAcc.loan__First_Installment_Date__c;
                    periodicFeeSetup.loan__Next_Recurring_Fee_Date__c = Date.newInstance(3000, 12, 31);
                    //create a charge..loan__charge__c.. with amount on LPP Periodic Fee Setup..
                    insertChargeAndLPT(periodicFeeSetup.loan__Fee__r.id, loanAcc.id, periodicFeeSetup.loan__Amount__c, false);


                    try {
                        SecureDML.updateRecords(periodicFeeSetup);
                        //update aps;
                    } catch (Exception e) {
                        system.debug('Exception ---' + e);
                    }
                }
            } else if (!loanAcc.Active_H_A__c &&
                (!String.isBlank(loanAcc.loan__Disbursal_Status__c) && (loanAcc.loan__Disbursal_Status__c.equals('Partially Disbursed') || loanAcc.loan__Disbursal_Status__c.equals('Fully Disbursed')))) {

                loan__Periodic_Fee_Setup__c periodicFeeSetup = [Select id, name, loan__Fee__r.Name, loan__Fee__r.id, loan__Active__c, loan__Amount__c from loan__Periodic_Fee_Setup__c
                    where loan__Lending_Account__r.id =: loanAcc.id and loan__Fee__r.Name like '%Home And Auto%'
                ];
                if (periodicFeeSetup != null) {
                    periodicFeeSetup.loan__Active__c = false;
                    periodicFeeSetup.loan__Amount__c = loanAcc.H_A_Subscription_Amount__c;
                    try {
                        SecureDML.updateRecords(periodicFeeSetup);
                    } catch (Exception e) {
                        system.debug('Exception ---' + e);
                    }
                }
            }
        }

    }
    public static void insertAPS(String loanAccId, Decimal feeAmount, Boolean markActive) {
        //insert active APS..
        loan__Payment_Mode__c paymentMode = new loan__Payment_Mode__c();
        //create LPT to satisfy above created charge..
        paymentMode = [Select id, name from loan__Payment_Mode__c where Name like '%Cash%'
            limit 1
        ];
        loan__Automated_Payment_Setup__c aps = new loan__Automated_Payment_Setup__c();
        aps.loan__CL_Contract__c = loanAccId;
        aps.loan__Amount_Type_Split_Factor__c = 1;
        aps.loan__Payment_Mode__c = paymentMode.id;
        aps.loan__Debit_Date__c = new loan.GlobalLoanUtilFacade().getCurrentSystemDate();
        aps.loan__Actual_Date__c = new loan.GlobalLoanUtilFacade().getCurrentSystemDate();
        aps.loan__Setup_Date__c = new loan.GlobalLoanUtilFacade().getCurrentSystemDate();
        aps.loan__Active__c = markActive;
        aps.loan__Type__c = 'RECURRING';
        aps.loan__Amount_Type__c = 'FIXED AMOUNT';
        aps.loan__Frequency__c = 'Monthly';
        aps.loan__Transaction_Amount__c = feeAmount;
        SecureDML.insertRecords(aps);

    }
    public static void insertChargeAndLPT(String loanFee, String loanAccId, Decimal feeAmount, Boolean markPaid) {

        loan__Charge__c charge = new loan__Charge__c();
        charge.loan__Fee__c = loanFee;
        charge.loan__Loan_Account__c = loanAccId;
        charge.loan__Date__c = new loan.GlobalLoanUtilFacade().getCurrentSystemDate();
        charge.loan__Total_Amount_Due__c = feeAmount;
        //charge.loan__Paid_Amount__c = feeAmount;
        //charge.loan__Original_Amount__c = feeAmount;
        SecureDML.insertRecords(charge);

         loan__Charge__c chargeUpdated = [Select id, name from loan__Charge__c where loan__Loan_Account__c =: loanAccId order by name desc limit 1];
         chargeUpdated.loan__Principal_Due__c = feeAmount;
         SecureDML.updateRecords(chargeUpdated);
         
        loan__Payment_Mode__c paymentMode = new loan__Payment_Mode__c();
        //create LPT to satisfy above created charge..
        paymentMode = [Select id, name from loan__Payment_Mode__c where Name like '%Cash%'
            limit 1
        ];
        loan__Loan_Payment_Transaction__c lpt = new loan__Loan_Payment_Transaction__c();
        lpt.loan__Loan_Account__c = loanAccId;
        lpt.loan__Payment_Mode__c = paymentMode.id;
        lpt.loan__Transaction_Amount__c = feeAmount;
        SecureDML.insertRecords(lpt);
    }
    public static Date updateNextDebitDateOnAPS(String loanId) {
        //String loanId = 'aAD0n0000008ZUHGA2';
        loan__loan_account__c primary = [Select loan__Next_Installment_Date__c, Contra_Loan_Account__r.id, loan__Maturity_Date_Current__c from
            loan__loan_account__c where id =: loanId 
        ];
        Date nextDue = primary.loan__Next_Installment_Date__c;
        System.debug('Contra_Loan_Account__r.id: ' + primary.Contra_Loan_Account__r.id);
        System.debug('nextDue: ' + nextDue);

        Date nextAmorDate = nextDue;
        Date lastAmorDate = null;

        List < loan__Repayment_Schedule__c > amorToUpdateList = [Select id, name, loan__Due_Date__c from loan__Repayment_Schedule__c where
            loan__Loan_Account__r.id =: primary.Contra_Loan_Account__r.id 
        ];
        if(amorToUpdateList.size() > 0){
            /*for (loan__Repayment_Schedule__c amorToUpdate: amorToUpdateList) {
                amorToUpdate.loan__Due_Date__c = nextAmorDate;
                lastAmorDate = nextAmorDate;
                nextAmorDate = nextAmorDate.addMonths(1);
            }
            SecureDML.updateRecords(amorToUpdateList); */
        }else{
            //lastAmorDate  = nextDue.addMonths(998);
            lastAmorDate = primary.loan__Maturity_Date_Current__c;
        }
        //update summary..
        list < loan__Repayment_Schedule_Summary__c > summaryList = [Select id, name, loan__RSS_Seq__c, loan__RSS_Repayment_Dt__c from loan__Repayment_Schedule_Summary__c
            where loan__RSS_Loan_Account__r.id =: primary.Contra_Loan_Account__r.id 
        ];
        for (loan__Repayment_Schedule_Summary__c summary: summaryList) {
            if (summary.loan__RSS_Seq__c == 1) {
                summary.loan__RSS_Repayment_Dt__c = nextDue;
            }
            if (summary.loan__RSS_Seq__c == 2) {
                summary.loan__RSS_Repayment_Dt__c = lastAmorDate;
            }
        }
        //update amorToUpdateList;
        SecureDML.updateRecords(summaryList);
        List < loan__Automated_Payment_Setup__c > apsList = [Select id, name from loan__Automated_Payment_Setup__c where
            loan__CL_Contract__r.id =: primary.Contra_Loan_Account__r.id
        ];
        for (loan__Automated_Payment_Setup__c aps: apsList) {
            aps.loan__Debit_Date__c = nextDue ;
        }
        SecureDML.updateRecords(apsList);

        //update current maturity date on contraLoanAcc..
        loan__loan_account__c contra = [Select loan__Maturity_Date_Current__c, Contra_Loan_Account__r.id from
            loan__loan_account__c where id =: primary.Contra_Loan_Account__r.id
        ];
        contra.loan__Maturity_Date_Current__c = lastAmorDate;
        //update contra;
        return lastAmorDate;
    }
    public static void processClosedObligationsMet(loan__loan_account__c loanAcc) {
        if (loanAcc.loan__Loan_Status__c.contains('Closed - Obligations met') && (loanAcc.Active_CO__c || loanAcc.Active_H_A__c)) {
            loan__loan_account__c contaLoanAcc = null;
            Date lastAmorDate = null;
            if (loanAcc.Contra_Loan_Account__c == null) {
                List < loan__loan_account__c > contaLoanAccList = [Select id, name, Active_CO__c, loan__Disbursal_Status__c, loan__Loan_Status__c from loan__loan_account__c where Lending_Product_Name__c like '%Ancillary Product%'
                    and
                    loan__Account__r.id =: loanAcc.loan__Account__r.id  limit 1
                ];
                if (contaLoanAccList.size() > 0) {
                    contaLoanAcc = contaLoanAccList.get(0);
                }
            }
            if (loanAcc.Contra_Loan_Account__c != null) {
                contaLoanAcc = [Select id, name, Active_CO__c, loan__Disbursal_Status__c, loan__Loan_Status__c from loan__loan_account__c where Lending_Product_Name__c like '%Ancillary Product%'
                    and
                    id =: loanAcc.Contra_Loan_Account__r.id  limit 1
                ];
            }
            if (contaLoanAcc != null) {
                if(contaLoanAcc.loan__Loan_Status__c.contains('Closed - Obligations met')){
                    contaLoanAcc.loan__Loan_Status__c = 'Active - Good Standing';
                    SecureDML.updateRecords(contaLoanAcc);
                }
                if (!String.isBlank(contaLoanAcc.loan__Disbursal_Status__c) && (contaLoanAcc.loan__Disbursal_Status__c.equals('Partially Disbursed') || contaLoanAcc.loan__Disbursal_Status__c.equals('Fully Disbursed'))) {
                    List<loan__Periodic_Fee_Setup__c> periodicFeeSetupList = [Select id, name, loan__Fee__r.Name, loan__Fee__r.id, loan__Fee__r.loan__Amount__c, loan__Active__c, loan__Amount__c from loan__Periodic_Fee_Setup__c
                        where loan__Lending_Account__r.id =: contaLoanAcc.id and loan__Fee__r.Name like '%Credit Optimizer%' 
                    ];
                    loan__Periodic_Fee_Setup__c periodicFeeSetup = null;
                    if(periodicFeeSetupList.size() > 0 ){
                        periodicFeeSetup = periodicFeeSetupList.get(0);
                    }
                    List<loan__Periodic_Fee_Setup__c> periodicFeeSetupHAList = [Select id, name, loan__Fee__r.Name, loan__Fee__r.id, loan__Fee__r.loan__Amount__c, loan__Active__c, loan__Amount__c from loan__Periodic_Fee_Setup__c
                        where loan__Lending_Account__r.id =: contaLoanAcc.id and loan__Fee__r.Name like '%Home And Auto%' 
                    ];
                    loan__Periodic_Fee_Setup__c periodicFeeSetupHA = null;
                    if(periodicFeeSetupHAList.size() > 0 ){
                        periodicFeeSetupHA = periodicFeeSetupHAList.get(0);
                    }
                    if (periodicFeeSetup != null && loanAcc.Active_CO__c) {
                        periodicFeeSetup.loan__Active__c = true;
                        periodicFeeSetup.loan__Amount__c = loanAcc.CO_Subscription_Amount__c;
                        periodicFeeSetup.loan__Next_Recurring_Fee_Date__c = loanAcc.loan__Next_Installment_Date__c;

                        List < loan__Automated_Payment_Setup__c > apsList = [Select id, name, loan__Active__c, loan__Debit_Date__c from loan__Automated_Payment_Setup__c where loan__CL_Contract__r.id =: contaLoanAcc.id ];
                        loan__Automated_Payment_Setup__c aps = null;
                        if (apsList.size() > 0) {
                            aps = apsList.get(0);
                            aps.loan__Active__c = true;
                            aps.loan__Transaction_Amount__c = periodicFeeSetup.loan__Amount__c;
                            //aps.loan__Debit_Date__c  = loanAcc.loan__Next_Installment_Date__c;
                            //aps.loan__Actual_Date__c = loanAcc.loan__Next_Installment_Date__c.addMonths(-1);
                            //aps.loan__Actual_Date__c = loanAcc.loan__Next_Installment_Date__c;
                            //aps.loan__Setup_Date__c = loanAcc.loan__Next_Installment_Date__c.addMonths(-1);
                            SecureDML.updateRecords(aps);
                        } else {
                            insertAPS(contaLoanAcc.id, periodicFeeSetup.loan__Amount__c, true);

                        }
                        lastAmorDate = updateNextDebitDateOnAPS(loanAcc.id);
                        try {
                            SecureDML.updateRecords(periodicFeeSetup);
                            //update aps;
                        } catch (Exception e) {
                            system.debug('Exception ---' + e);
                        }
                    }
                    if (periodicFeeSetupHA != null && loanAcc.Active_H_A__c) {
                        periodicFeeSetupHA.loan__Active__c = true;
                        //periodicFeeSetupHA.loan__Next_Recurring_Fee_Date__c = loanAcc.loan__Next_Installment_Date__c;
                        periodicFeeSetupHA.loan__Next_Recurring_Fee_Date__c = Date.newInstance(3000, 12, 31);
                        periodicFeeSetupHA.loan__Amount__c = loanAcc.H_A_Subscription_Amount__c;
                        SecureDML.updateRecords(periodicFeeSetupHA);

                        //create a charge..loan__charge__c.. with amount on LPP Periodic Fee Setup..
                        insertChargeAndLPT(periodicFeeSetupHA.loan__Fee__r.id, contaLoanAcc.id, periodicFeeSetupHA.loan__Amount__c, false);
                    }
                } else if ((!String.isBlank(contaLoanAcc.loan__Disbursal_Status__c) && contaLoanAcc.loan__Disbursal_Status__c.equals('Pending Disbursal')) || String.isBlank(contaLoanAcc.loan__Disbursal_Status__c)) {
                    contaLoanAcc.loan__Loan_Status__c = 'Approved';
                    if (loanAcc.Active_CO__c) {
                        contaLoanAcc.Active_CO__c = true;
                        contaLoanAcc.CO_Subscription_Amount__c = loanAcc.CO_Subscription_Amount__c;
                    } else {
                        contaLoanAcc.Active_CO__c = false;
                        contaLoanAcc.CO_Subscription_Amount__c = 0;
                    }
                    if (loanAcc.Active_H_A__c) {

                        contaLoanAcc.Active_H_A__c = true;
                        contaLoanAcc.H_A_Subscription_Amount__c = loanAcc.H_A_Subscription_Amount__c;
                    } else {

                        contaLoanAcc.Active_H_A__c = false;
                        contaLoanAcc.H_A_Subscription_Amount__c = 0;
                    }
                    //contaLoanAcc.CO_Subscription_Amount__c = loanAcc.CO_Subscription_Amount__c;
                    //contaLoanAcc.H_A_Subscription_Amount__c = loanAcc.H_A_Subscription_Amount__c;
                    contaLoanAcc.Contra_Loan_Account__c = null;
                    SecureDML.updateRecords(contaLoanAcc);

                    loan__Payment_Mode__c paymentMode = new loan__Payment_Mode__c();
                    paymentMode = [Select id, name from loan__Payment_Mode__c where Name like '%Cash%'
                        limit 1
                    ];
                    //first create disbursal..
                    loan__Loan_Disbursal_Transaction__c ldt = new loan__Loan_Disbursal_Transaction__c();
                    ldt.loan__Loan_Account__c = contaLoanAcc.id;
                    ldt.loan__Financed_Amount__c = 1;
                    ldt.loan__Refinanced_Amount__c = 0;
                    ldt.loan__Disbursed_Amt__c = 1;
                    ldt.loan__Pre_Paid_Fee__c = 0;
                    ldt.loan__Transaction_Creation_Date__c = new loan.GlobalLoanUtilFacade().getCurrentSystemDate();
                    ldt.loan__Mode_of_Payment__c = paymentMode.id;
                    SecureDML.insertRecords(ldt);

                    loan__Automated_Payment_Setup__c apsNew = [Select id, name, loan__Active__c, loan__Debit_Date__c from loan__Automated_Payment_Setup__c where loan__CL_Contract__r.id =: contaLoanAcc.id];
                    //apsNew.loan__Debit_Date__c = loanAcc.loan__Next_Installment_Date__c;
                    //apsNew.loan__Actual_Date__c = loanAcc.loan__Next_Installment_Date__c.addMonths(-1);
                    //apsNew.loan__Actual_Date__c = loanAcc.loan__Next_Installment_Date__c;
                    //apsNew.loan__Setup_Date__c = loanAcc.loan__Next_Installment_Date__c.addMonths(-1);
                    if (loanAcc.Active_CO__c) {
                        apsNew.loan__Active__c = true;
                        apsNew.loan__Transaction_Amount__c = loanAcc.CO_Subscription_Amount__c;
                    }
                    SecureDML.updateRecords(apsNew);
                    lastAmorDate = updateNextDebitDateOnAPS(loanAcc.id);
                }


                //update feeEndDate after new schedule is generated..
                if (loanAcc.Active_H_A__c) {
                    List<loan__Periodic_Fee_Setup__c> periodicFeeSetupHAList = [Select id, name, loan__Fee__r.Name, loan__Fee__r.id, loan__Fee__r.loan__Amount__c, loan__Active__c, loan__Amount__c from loan__Periodic_Fee_Setup__c
                        where loan__Lending_Account__r.id =: contaLoanAcc.id and loan__Fee__r.Name like '%Home And Auto%' 
                    ];
                    loan__Periodic_Fee_Setup__c periodicFeeSetupHA = null;
                    if(periodicFeeSetupHAList.size() > 0){
                        periodicFeeSetupHA = periodicFeeSetupHAList.get(0);
                    }
                    if(periodicFeeSetupHA != null){
                        periodicFeeSetupHA.loan__Amount__c = loanAcc.H_A_Subscription_Amount__c;
                        //periodicFeeSetupHA.loan__Next_Recurring_Fee_Date__c = loanAcc.loan__Next_Installment_Date__c;
                        periodicFeeSetupHA.loan__Next_Recurring_Fee_Date__c = Date.newInstance(3000, 12, 31);
                        SecureDML.updateRecords(periodicFeeSetupHA);
                    }
                }

                List < loan__Periodic_Fee_Setup__c > periodicFeeSetupList = [Select id, name, loan__Fee__r.Name, loan__Fee__r.id, loan__Active__c, loan__Amount__c from loan__Periodic_Fee_Setup__c
                    where loan__Lending_Account__r.id =: loanAcc.id and loan__Fee__r.Name like '%Credit Optimizer%' 
                ];
                loan__Periodic_Fee_Setup__c periodicFeeSetup = null;
                if (periodicFeeSetupList.size() > 0) {
                    periodicFeeSetup = periodicFeeSetupList.get(0);
                    periodicFeeSetup.loan__Active__c = false;
                    periodicFeeSetup.loan__Amount__c = loanAcc.CO_Subscription_Amount__c;
                    /* List<loan__Automated_Payment_Setup__c> apsList = [Select id, name, loan__Active__c from loan__Automated_Payment_Setup__c where loan__Active__c = true 
                                                                       and loan__CL_Contract__r.id =: loanAcc.id];
                     loan__Automated_Payment_Setup__c aps = null;
                     if(apsList.size() > 0){
                         aps = apsList.get(0);
                         aps.loan__Active__c = false;
                         SecureDML.updateRecords(aps);
                     } */
                    SecureDML.updateRecords(periodicFeeSetup);
                }
                List < loan__Periodic_Fee_Setup__c > periodicFeeSetupListHA = [Select id, name, loan__Fee__r.Name, loan__Fee__r.id, loan__Active__c, loan__Amount__c from loan__Periodic_Fee_Setup__c
                    where loan__Lending_Account__r.id =: loanAcc.id and loan__Fee__r.Name like '%Home And Auto%' 
                ];
                loan__Periodic_Fee_Setup__c periodicFeeSetupHA = null;
                if (periodicFeeSetupListHA.size() > 0) {
                    periodicFeeSetupHA = periodicFeeSetupListHA.get(0);
                    periodicFeeSetupHA.loan__Active__c = false;
                    periodicFeeSetupHA.loan__Amount__c = loanAcc.H_A_Subscription_Amount__c;
                    /* List<loan__Automated_Payment_Setup__c> apsList = [Select id, name, loan__Active__c from loan__Automated_Payment_Setup__c where loan__Active__c = true 
                                                                       and loan__CL_Contract__r.id =: loanAcc.id];
                     loan__Automated_Payment_Setup__c aps = null;
                     if(apsList.size() > 0){
                         aps = apsList.get(0);
                         aps.loan__Active__c = false;
                         SecureDML.updateRecords(aps);
                     } */
                    SecureDML.updateRecords(periodicFeeSetupHA);
                }

                if (loanAcc.Active_CO__c) {
                    contaLoanAcc.Active_CO__c = true;
                    contaLoanAcc.CO_Subscription_Amount__c = loanAcc.CO_Subscription_Amount__c;
                }
                if (loanAcc.Active_H_A__c) {
                    contaLoanAcc.Active_H_A__c = true;
                    contaLoanAcc.H_A_Subscription_Amount__c = loanAcc.H_A_Subscription_Amount__c;
                }
                loanAcc.Active_CO__c = false;
                loanAcc.Active_H_A__c = false;
                loanAcc.CO_Subscription_Amount__c = 0;
                loanAcc.H_A_Subscription_Amount__c = 0;
                loanAcc.Contra_Loan_Account__c = null;

                contaLoanAcc.Contra_Loan_Account__c = null;
                contaLoanAcc.loan__Maturity_Date_Current__c = lastAmorDate;
                //contaLoanAcc.CO_Subscription_Amount__c = loanAcc.CO_Subscription_Amount__c;
                //contaLoanAcc.H_A_Subscription_Amount__c = loanAcc.H_A_Subscription_Amount__c;
                SecureDML.updateRecords(loanAcc);
                SecureDML.updateRecords(contaLoanAcc);
            }

        }
    }
    public static void processClosedWrittenOff(loan__loan_account__c loanAcc) {
        if (loanAcc.loan__Loan_Status__c.contains('Closed- Written Off')) {
            if (loanAcc.Active_CO__c) {
                loanAcc.Active_CO__c = false;
                loanAcc.CO_Subscription_Amount__c = 0;
                //update loanAcc;
            }
            if (loanAcc.Active_H_A__c) {
                loanAcc.Active_H_A__c = false;
                loanAcc.H_A_Subscription_Amount__c = 0;
                //update loanAcc;
            }
            if (loanAcc.Active_LPP__c || loanAcc.LPP_Prepaid__c) {
                loanAcc.Active_LPP__c= false;
                loanAcc.LPP_Prepaid__c = false;
                //update loanAcc;
            }
            SecureDML.updateRecords(loanAcc);
            List < loan__Periodic_Fee_Setup__c > periodicFeeSetupList = [Select id, name, loan__Fee__r.Name, loan__Fee__r.id, loan__Active__c, loan__Amount__c from loan__Periodic_Fee_Setup__c
                where loan__Lending_Account__r.id =: loanAcc.id and loan__Active__c = true and loan__Fee__r.Name like '%Credit Optimizer%' 
            ];
            system.debug('periodicFeeSetupList******************'+periodicFeeSetupList);
            loan__Periodic_Fee_Setup__c periodicFeeSetup = null;
            if (periodicFeeSetupList.size() > 0) {
                periodicFeeSetup = periodicFeeSetupList.get(0);
                periodicFeeSetup.loan__Active__c = false;
                periodicFeeSetup.loan__Amount__c = loanAcc.CO_Subscription_Amount__c;


                /* List<loan__Automated_Payment_Setup__c> apsList = [Select id, name, loan__Active__c from loan__Automated_Payment_Setup__c where loan__Active__c = true 
                                                                   and loan__CL_Contract__r.id =: loanAcc.id];
                 loan__Automated_Payment_Setup__c aps = null;
                 if(apsList.size() > 0){
                     aps = apsList.get(0);
                     aps.loan__Active__c = false;
                     SecureDML.updateRecords(aps);
                 } */
                SecureDML.updateRecords(periodicFeeSetup);
            }
            List < loan__Periodic_Fee_Setup__c > periodicFeeSetupListHA = [Select id, name, loan__Fee__r.Name, loan__Fee__r.id, loan__Active__c, loan__Amount__c from loan__Periodic_Fee_Setup__c
                where loan__Lending_Account__r.id =: loanAcc.id and loan__Active__c = true and loan__Fee__r.Name like '%Home And Auto%' 
            ];
            system.debug('periodicFeeSetupListHA************'+periodicFeeSetupListHA);
            loan__Periodic_Fee_Setup__c periodicFeeSetupHA = null;
            if (periodicFeeSetupListHA.size() > 0) {
                periodicFeeSetupHA = periodicFeeSetupListHA.get(0);
                periodicFeeSetupHA.loan__Active__c = false;
                periodicFeeSetupHA.loan__Amount__c = loanAcc.H_A_Subscription_Amount__c;
                /* List<loan__Automated_Payment_Setup__c> apsList = [Select id, name, loan__Active__c from loan__Automated_Payment_Setup__c where loan__Active__c = true 
                                                                   and loan__CL_Contract__r.id =: loanAcc.id];
                 loan__Automated_Payment_Setup__c aps = null;
                 if(apsList.size() > 0){
                     aps = apsList.get(0);
                     aps.loan__Active__c = false;
                     SecureDML.updateRecords(aps);
                 } */
                SecureDML.updateRecords(periodicFeeSetupHA);
            }
            List < loan__Periodic_Fee_Setup__c > periodicFeeSetupLPPList = [Select id, name, loan__Fee__r.Name, loan__Fee__r.id, loan__Active__c, loan__Amount__c from loan__Periodic_Fee_Setup__c
                where loan__Lending_Account__r.id =: loanAcc.id and loan__Active__c = true and loan__Fee__r.Name like '%Loan Protection Plan%' 
            ];
            system.debug('periodicFeeSetupList******************'+periodicFeeSetupList);
            loan__Periodic_Fee_Setup__c periodicFeeSetupLPP = null;
            if (periodicFeeSetupLPPList.size() > 0) {
                periodicFeeSetupLPP = periodicFeeSetupLPPList.get(0);
                periodicFeeSetupLPP.loan__Active__c = false;


                /* List<loan__Automated_Payment_Setup__c> apsList = [Select id, name, loan__Active__c from loan__Automated_Payment_Setup__c where loan__Active__c = true 
                                                                   and loan__CL_Contract__r.id =: loanAcc.id];
                 loan__Automated_Payment_Setup__c aps = null;
                 if(apsList.size() > 0){
                     aps = apsList.get(0);
                     aps.loan__Active__c = false;
                     SecureDML.updateRecords(aps);
                 } */
                SecureDML.updateRecords(periodicFeeSetupLPP);
            }

        }
    }
    public static loan__loan_account__c createContraLoanAccount(loan__loan_account__c loanAcc) {
        loan__loan_product__c lendingProduct = [Select id, name, loan__Fee_Set__r.id, RecordTypeId from loan__Loan_Product__c where name like 'Ancillary Product' ];
        RecordType recordType = [Select id, name, IsActive, SobjectType from recordType where name in ('Loan') and SobjectType = 'loan__Loan_Account__c' and IsActive = true ];
        loan__loan_account__c contraLoanAcc = new loan__loan_account__c();
        contraLoanAcc.RecordTypeId = recordType.id;
        contraLoanAcc.loan__Account__c = loanAcc.loan__Account__r.id;
        contraLoanAcc.loan__Contract_Type__c = 'New';
        contraLoanAcc.loan__Loan_Product_Name__c = lendingProduct.id;
        contraLoanAcc.loan__Loan_Status__c = 'Approved';
        contraLoanAcc.loan__Fee_Set__c = lendingProduct.loan__Fee_Set__r.id;
        contraLoanAcc.loan__Loan_Amount__c = 1;
        contraLoanAcc.loan__Expected_Disbursal_Date__c = new loan.GlobalLoanUtilFacade().getCurrentSystemDate();
        contraLoanAcc.loan__Expected_Repayment_Start_Date__c = new loan.GlobalLoanUtilFacade().getCurrentSystemDate().addMonths(1);
        contraLoanAcc.loan__Number_of_Installments__c = 999;
        contraLoanAcc.loan__Amortization_Schedule_Generated__c = false;
        contraLoanAcc.Contra_Loan_Account__c = loanAcc.id;
        contraLoanAcc.Active_CO__c = false;
        contraLoanAcc.Active_H_A__c = false;
        //contraLoanAcc.CO_Subscription_Amount__c = loanAcc.CO_Subscription_Amount__c;
        //contraLoanAcc.H_A_Subscription_Amount__c = loanAcc.H_A_Subscription_Amount__c;
        contraLoanAcc.CO_Subscription_Amount__c = 0;
        contraLoanAcc.H_A_Subscription_Amount__c = 0;
        contraLoanAcc.loan__Frequency_of_Loan_Payment__c = loanAcc.loan__Frequency_of_Loan_Payment__c;
        loan.BorrowerAPI2 bAPI = loan.APIFactory.getBorrowerAPI2();
        loan__Loan_Account__c loanAccNew = bAPI.createContract(contraLoanAcc,
            null,
            null,
            null,
            null,
            null);
        System.debug(loanAccNew.id);
        return loanAccNew;
    }    

    
}