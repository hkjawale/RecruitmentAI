public with sharing class PromptController {
      
    //AuraEnabled annotation makes your methods available to your Lightning components 
    @AuraEnabled
    public static String getSkills(Id candidateId) {
         if (candidateId == null ) {
            return 'Error: No Candidate ID was provided.';
        }
       
        System.debug('Going to process candidate: '+ candidateId);
        String extractedSkills;

        // Execute a Prompt Template using the Connect API in Apex
        // Create inputs
        Map<String, String> CandidateProfile  = new Map<String, String>();
        CandidateProfile.put('id', candidateId);
        ConnectApi.WrappedValue CandidateProfileValue = new ConnectApi.WrappedValue();
        CandidateProfileValue.value = CandidateProfile;
        Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();
        inputParams.put('Input:CandidateProfile', CandidateProfileValue);

        // Configure invocation parameters
        ConnectApi.EinsteinPromptTemplateGenerationsInput executeTemplateInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        executeTemplateInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
        executeTemplateInput.additionalConfig.applicationName = 'PromptBuilderPreview';
        executeTemplateInput.isPreview = false;
        executeTemplateInput.inputParams = inputParams;

        try {
            // Call the service
            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation generationsOutput = ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                'Extract_Skills_From_Resume_File',
                executeTemplateInput
            );
            ConnectApi.EinsteinLLMGenerationItemOutput response = generationsOutput.generations[0];
            extractedSkills = response.text;
            System.debug('The extracted skills are: ' + extractedSkills);
            return extractedSkills;
        } catch (Exception e) {
            System.debug(e.getMessage());
            throw e;
        }    
    }  
}