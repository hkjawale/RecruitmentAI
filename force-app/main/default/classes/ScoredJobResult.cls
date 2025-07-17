// This class defines the data structure for a scored job result.
// It implements the 'Comparable' interface to handle its own sorting logic.
public class ScoredJobResult implements Comparable {

    @AuraEnabled @InvocableVariable(label='Job ID' description='The Salesforce ID of the Position record.')
    public String jobId;

    @AuraEnabled @InvocableVariable(label='Job Title' description='The title of the job position.')
    public String jobTitle;

    @AuraEnabled @InvocableVariable(label='Match Score' description='The AI-calculated match score from 0 to 100.')
    public Integer score;

    @AuraEnabled @InvocableVariable(label='Justification' description='The AI-generated reason for the score.')
    public String justification;

    // The 'compareTo' method is required by the 'Comparable' interface.
    // It allows a list of these objects to be sorted directly using List.sort().
    public Integer compareTo(Object compareTo) {
        ScoredJobResult compareToResult = (ScoredJobResult)compareTo;
        
        // Sort descending: higher score first.
        if (score == null) return 1;
        if (compareToResult.score == null) return -1;
        if (score > compareToResult.score) {
            return -1;
        } else if (score < compareToResult.score) {
            return 1;
        } else {
            return 0;
        }
    }
}