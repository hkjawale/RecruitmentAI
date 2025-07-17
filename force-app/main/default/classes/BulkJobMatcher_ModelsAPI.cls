public class BulkJobMatcher_ModelsAPI {
    
    // Helper class to structure the JSON sent to the AI.
    public class JobInfo {
        public String jobId;
        public String title;
        public String requiredSkills;
    }

    /* 
     * This method is AuraEnabled so it can be called from the Lightning Web Component.
     * It directly returns a List of ScoredJobResult, which the LWC can process. 
    */
    @AuraEnabled
    public static List<ScoredJobResult> getBulkMatchScores(String candidateSkills) {

        // Get all the open job position records and prepare the JSON payload
        List<JobInfo> jobInfoList = new List<JobInfo>();
        Map<Id, Position__c> jobMap = new Map<Id, Position__c>([
            SELECT Id, Name, Skills_Required__c 
            FROM Position__c 
            WHERE Status__c = 'Open'
        ]);
        
        for (Position__c job : jobMap.values()) {
            JobInfo info = new JobInfo();
            info.jobId = job.Id;
            info.title = job.Name;
            info.requiredSkills = job.Skills_Required__c;
            jobInfoList.add(info);
        }
        String jobListJson = JSON.serialize(jobInfoList);

        // Construct the entire prompt within Apex. You can make it more 
        String fullPrompt = 'You are an expert AI recruiting analyst. Your task is to compare a candidate\'s list of skills with a list of open jobs provided as a JSON array.\n\n' +
                            'For each job in the JSON list, calculate a "match score" from 0 to 100 and provide a brief justification.\n\n' +
                            '- Analyze the candidate\'s skills against the `requiredSkills` for each job.\n' +
                            '- Consider synonyms and related concepts.\n' +
                            '- Return a valid JSON array containing an object for each job you evaluated. Each object must include the job\'s original `jobId`, your calculated `score`, and a `justification`.\n\n' +
                            '**Output Format:** You MUST return only a single, valid JSON array. Do not add any other text or comments.\n' +
                            'Example output:\n' +
                            '`[{"jobId": "a018c00000_JOB1_ID", "score": 85, "justification": "Strong match for core development skills."}, {"jobId": "a018c00000_JOB2_ID", "score": 50, "justification": "Missing key database management skills."}]`\n\n' +
                            '---\n\n' +
                            '**Candidate\'s Skills:**\n' + candidateSkills + '\n\n' +
                            '**JSON List of Open Jobs:**\n' + jobListJson;

        // Use the Models API that provides Apex classes to connect your application to large language models (LLMs).
        String jsonResponse;
        try {
            System.debug('Calling the Models API now...');
            aiplatform.ModelsAPI.createGenerations_Request predRequest = new aiplatform.ModelsAPI.createGenerations_Request();
            predRequest.modelName = 'sfdc_ai__DefaultGPT41';
            
            aiplatform.ModelsAPI_GenerationRequest requestBody = new aiplatform.ModelsAPI_GenerationRequest();
            predRequest.body = requestBody;
            requestBody.prompt = fullPrompt;
            
            aiplatform.ModelsAPI modelsAPI = new aiplatform.ModelsAPI();
            aiplatform.ModelsAPI.createGenerations_Response response = modelsAPI.createGenerations(predRequest);
            
            jsonResponse = response.Code200.generation.generatedText;
            System.debug('JSON response...' + jsonResponse);

        } catch(aiplatform.ModelsAPI.createGenerations_ResponseException e) {
            System.debug('Response code: ' + e.responseCode);
            System.debug('The following exception occurred: ' + e);
            // Throw an AuraHandledException to send a user-friendly error to the LWC
            throw new AuraHandledException('Error connecting to the AI service. Please contact your administrator.');
        }

        // Parse the AI response and combine with original job data
        List<ScoredJobResult> finalResults = new List<ScoredJobResult>();
        try {
            List<Object> aiScoredListGeneric = (List<Object>)JSON.deserializeUntyped(jsonResponse);

            for(Object genericResult : aiScoredListGeneric){
                Map<String, Object> aiResultMap = (Map<String, Object>)genericResult;
                
                String resultJobId = (String)aiResultMap.get('jobId');
                Position__c originalJob = jobMap.get(resultJobId);
                
                if(originalJob != null) {
                    ScoredJobResult finalResult = new ScoredJobResult();
                    finalResult.jobId = resultJobId;
                    finalResult.jobTitle = originalJob.Name;
                    finalResult.score = (Integer)aiResultMap.get('score');
                    finalResult.justification = (String)aiResultMap.get('justification');
                    finalResults.add(finalResult);
                }
            }
        } catch(Exception e) {
            System.debug('Error parsing JSON response from AI: ' + e.getMessage());
            throw new AuraHandledException('The AI returned an invalid response. Please try again.');
        }
        
        // Sort and filter the results. 
        // We are filtering out results that have a less than 60% match score if the no of matches are more than 3. Adjust it per your preference. 
        finalResults.sort();
        if (jobMap.size() > 3) {
            List<ScoredJobResult> filteredResults = new List<ScoredJobResult>();
            for (ScoredJobResult result : finalResults) {
                if (result.score >= 60) {
                    filteredResults.add(result);
                }
            }
            return filteredResults;
        }
        System.debug('Final results...' + finalResults);
        return finalResults;
    }
}