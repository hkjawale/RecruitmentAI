import { LightningElement, api, track } from 'lwc';
import getBulkMatchScores from '@salesforce/apex/BulkJobMatcher_ModelsAPI.getBulkMatchScores';
import getSkills from '@salesforce/apex/PromptController.getSkills';


const columns = [
    {
        label: 'Job Title',
        fieldName: 'jobUrl', // This field will hold the URL of the job record in Salesforce
        type: 'url',
        typeAttributes: {
            label: { fieldName: 'jobTitle' }, // This field provides the link's text
            target: '_blank' // Open the link in a new browser tab
        }
    },
    { label: 'Match Score', fieldName: 'score', type: 'number', cellAttributes: { alignment: 'left' } },
    { label: 'AI Justification', fieldName: 'justification', type: 'text', wrapText: true },
];

export default class JobMatcherLWC extends LightningElement {
    @api recordId; // Automatically gets the record ID from the page
    
    @track jobResults;
    @track error;
    @track isLoading = false;
    columns = columns;

    candidateSkills;

    async extractSkills() {
        try {
            this.candidateSkills = await getSkills({ candidateId: this.recordId });
            
            if(!this.candidateSkills) {
                this.error = 'Could not extract skills from the resume. Please ensure a resume file is attached or that the AI could read it.';
                this.isLoading = false;
            }
        } catch (error) {
            this.error = 'Error extracting skills: ' + (error.body ? error.body.message : error.message);
            this.isLoading = false;
        }
    }

    async handleAnalyzeClick() {
        this.isLoading = true;
        this.error = undefined;
        this.jobResults = undefined;

        await this.extractSkills();

        if (this.candidateSkills) {
            try {
                const results = await getBulkMatchScores({ candidateSkills: this.candidateSkills });
                
                if (results && results.length > 0) {
                    this.jobResults = results.map(row => {
                        // Create the standard Salesforce record URL
                        const recordUrl = `/lightning/r/Position__c/${row.jobId}/view`;
                        // Return a new object that includes all original properties (...) plus the new jobUrl property
                        return { ...row, jobUrl: recordUrl };
                    });
                } else {
                    this.error = 'No matching jobs were found, or the AI did not return any results.';
                }
                this.isLoading = false;
            } catch (error) {
                this.error = error.body ? error.body.message : 'An unknown error occurred.';
                this.isLoading = false;
            }
        }
    }
}