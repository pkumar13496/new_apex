/********************************************************************************************************************************************************************************
 * Class   : CLS_APSWrapperAPI
 * Company : GoEasy
 * Author  : Ajeet
 ********************************************************************************************************************************************************************************/
@RestResource(urlMapping='/createBluePayAccount')
global with sharing class CLS_APSWrapperAPI {
    
    global class bluepayWrapperRequest {
        global String loanNumber;
        global String bluepayToken;
    }
    global class bluepayWrapperResponse {
        global Integer status;
        global String message;
    }
    
    @HttpPost
    global static bluepayWrapperResponse doPost() {
       
        String jsonStr = null;
        
        bluepayWrapperRequest blupePayInstance;
        bluepayWrapperResponse bluePayresponse = new bluepayWrapperResponse();
        bluePayresponse.status = 201;
        
        if(RestContext.request.requestBody != null) {
            jsonStr = RestContext.request.requestBody.toString();
            blupePayInstance = (bluepayWrapperRequest )JSON.deserialize(jsonStr, bluepayWrapperRequest.class); 
        	System.debug(LoggingLevel.ERROR, 'wrapperinstance ===> ' + blupePayInstance);
        }
        if(blupePayInstance != null && blupePayInstance.loanNumber != null){
            bluePayresponse.message = CLS_APSWrapperHandler.callAPSCreationFromProduct(blupePayInstance);
            return bluePayresponse;
        }
        else{
            bluePayresponse.status = 400;
            bluePayresponse.message = CLS_Constants.ERR_MSG;
            return bluePayresponse;
        }
    }
    

}