/**
 * Author : Prithvi
 */
public class CLS_OneSpanDownloadDocCallout {
    
    public static void getDocument(String applicaitonId, String packageId, String documentId, String fileName) {

        if(String.isBlank(packageId) || String.isBlank(documentId)) {
            throw new InvalidDocOrPkgeException('Invalid Package Id/Document Id');
        }
        Map<String,Object> requestParamMap = new Map<String,Object>{'packageId' => packageId, 'documentId' => documentId, 'applicationId' => applicaitonId, 'fileName' => fileName};
        Map<String,Object> queryIdMap = new Map<String,Object>();
        intframework.AbstractIntegrationService baseintegrationService = intframework.IntegrationServiceFactory.getBaseIntegrationService();
        intframework.BaseIntegrationResponse responseObject = (intframework.BaseIntegrationResponse)baseintegrationService.runSynchronousIntegrationService('OneSpan','OneSpan',3,queryIdMap,requestParamMap);
    }

    public class InvalidDocOrPkgeException extends Exception {}
}