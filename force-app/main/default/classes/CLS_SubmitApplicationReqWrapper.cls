global class CLS_SubmitApplicationReqWrapper {
    
    global String appId;
	global String consent;
    
    public static CLS_SubmitApplicationReqWrapper parse(String json){
		return (CLS_SubmitApplicationReqWrapper) System.JSON.deserialize(json, CLS_SubmitApplicationReqWrapper.class);
	}

}