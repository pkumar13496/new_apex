/**
 * Author : Prithvi
 */
global class CLS_OneSpanDownloadDocAdapter extends Intframework.BaseIntegrationAdapter {
    
    String packageId;
    String documentId;
    Id applicationId;
    String fileName;
    global override virtual String generateRequestBody(Map<String, Object> requestMap) {
        packageId = (String)requestMap.get('packageId');
        documentId = (String)requestMap.get('documentId');
        applicationId = (String)requestMap.get('applicationId');
        fileName = (String)requestMap.get('fileName');
        return null;
    }

    private void prepareRequest(HttpRequest request) {
        request.setEndpoint(request.getEndpoint() + packageId + '/documents/' + documentId + '/pdf');
        //request.setHeader('Accept','application/pdf');
        request.setHeader('Authorization', 'Basic ' + CLS_OneSpanUtils.getInstance().oneSpanAPIkey);
    }

    global virtual override HttpResponse sendRequest(HttpRequest request) {
        HttpResponse httpResponse = null;
        Http http = new Http();
        prepareRequest(request);
        try {           
            httpResponse = http.send(request);
        } catch ( Exception e ) {
            System.debug(LoggingLevel.DEBUG, 'Exception sending request --- ' + e);
            throw e;
        }
                
        return httpResponse;
    }

    global Override intframework.BaseIntegrationResponse createResponse(HttpResponse httpResponse) {
        //The response body is parsed into JSON name value pairs
        intframework.BaseIntegrationResponse response = new intframework.BaseIntegrationResponse(httpResponse);
        if(httpResponse != null){
            System.debug('--- applicationId '+ applicationId);
            System.debug('--- documentId '+ documentId);
            fileName = fileName + '.pdf';
            System.debug('--- fileName '+ fileName);
            CLS_FileUploadCallout.fileUpload(applicationId, fileName, httpResponse.getBodyAsBlob(), documentId);
        }
        return response;
    }


}