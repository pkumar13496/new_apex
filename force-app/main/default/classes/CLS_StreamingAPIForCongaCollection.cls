global class CLS_StreamingAPIForCongaCollection implements clcommon.PortalCustomRemoteAPI1{
	global clcommon.Response invokeAction(String componentStrName, String[] disclosureNames, Map<String, Object> values){

		clcommon.Response res = new clcommon.Response();
		List<clcommon.PortalCustomRemoteActionRecord> records = new List<clcommon.PortalCustomRemoteActionRecord>{};
		List<Object> data = new List<Object>();
		String flowName = (String)values.get('flowName');
		String CureIdName = (String)values.get('cureActionId');
		String settlmentId = values.get('settlementRecordId') != null ? (String)values.get('settlementRecordId') : null;
		String loanName = (String)values.get('contractName');
		if (flowName == 'AOT' && CureIdName != ''){
			list<Loan_Account_Cure_Request__c> setlst = [select id, Process_Status__c
			                                             from Loan_Account_Cure_Request__c
			                                             where id = :CureIdName ];
			Map<String, Object> fields = new Map<String, Object>{};
			if (setlst != null && setlst.size() > 0 && setlst[0].Process_Status__c == 'DOCUMENT SENT FOR SIGNING'){
				fields.put('AOTStatus', 'DOCUMENT SENT FOR SIGNING');
				clcommon.PortalCustomRemoteActionRecord record = new clcommon.PortalCustomRemoteActionRecord(null, fields);
				records.add(record);
				res = clcommon.PortalActions.getCustomRemoteActionResponse(records);
			} else{
				res.status = 'PENDING';
			}
		}

		if (flowName == 'Settlement' && settlmentId != null){
			list<Settlement_Request__c> setlst = [SELECT id, Settlement_Status__c
			                                      FROM Settlement_Request__c
			                                      WHERE Id = :settlmentId ];
			Map<String, Object> fields = new Map<String, Object>{};
			if (setlst != null && setlst.size() > 0 && setlst[0].Settlement_Status__c == 'Document Generated & Emailed'){
				fields.put('settlementStatus', 'Document Generated & Emailed');
				clcommon.PortalCustomRemoteActionRecord record = new clcommon.PortalCustomRemoteActionRecord(null, fields);
				records.add(record);
				res = clcommon.PortalActions.getCustomRemoteActionResponse(records);
			} else{
				res.status = 'PENDING';
			}
		}
		return res;
	}
}