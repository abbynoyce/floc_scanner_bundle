% This script loads the files from floc_scanner and calculates proportion
% correct, d', and reaction time for the auditory and visual 2-back tasks.
%
% Abigail Noyce, January 2015.

% Set variables
subjects = {'AA','CC','EC','EL','KK','NP','OG','RU','SY','TC','TL','TV',...
    'UU','VV','WW'};%'DD' 
nRuns = 8; % how many runs should each subject have?

% Set constants
inputfolder = '../../results/scanner task outputs';
nConditions = 2; % A and V
nBlocks = 8;

correct = nan(numel(subjects), nConditions);
medRT = correct;
dprime = correct;

for s = 1:numel(subjects)
    subID = subjects{s}
    files = dir([ inputfolder filesep subID '*']);
    if numel(files) ~= nRuns
        'ERROR: Incorrect number of files for this subject'
        continue
    end
    
    % Pre-blank
    visResponses = [];
    visRTs = [];
    visCorrResponse = [];
    
    audResponses = [];
    audRTs = [];
    audCorrResponse = [];
    
    % Load data
    for f = 1:numel(files)
        % Load this file
        load([inputfolder filesep files(f).name], 'responses', 'corr_response', 'order');
        
        % Clear index variables
        v = []; % index of visual blocks
        a = []; % index of auditory blocks
        
        % Sort out which blocks of this run are members of the relevant
        % conditions.
        for b = 1:nBlocks
            blocktype = order{b};
            switch blocktype(3)
                case 'P' % passive, do nothing
                case 'A' % active, add to analysis chain
                    switch blocktype(1)
                        case 'V' % visual
                            v = [v b]
                        case 'A' % auditory   
                            a = [a b]
                    end
            end
        end % block loop
        
        % Add this run's data to matrices
        visResponses = [visResponses responses(:,v,1)];
        visRTs = [visRTs responses(:,v,2)];
        visCorrResponse = [visCorrResponse corr_response(:,v)];
        
        audResponses = [audResponses responses(:,a,1)];
        audRTs = [audRTs responses(:,a,2)];
        audCorrResponse = [audCorrResponse corr_response(:,a)];
    end % file loop
    
    % Get values for this subject
    % Theoretical question: combine then average, or vice versa? Combine
    % then average.
    
    correct(s,1) = sum(sum(visCorrResponse == visResponses)) / numel(visResponses);
    correct(s,2) = sum(sum(audCorrResponse == audResponses)) / numel(audResponses);
    
    medRT(s,1) = median(reshape(visRTs, [1 numel(visRTs)]));
    medRT(s,2) = median(reshape(audRTs, [1 numel(audRTs)]));
    
    vishitrate = sum(sum(visCorrResponse == 1 & visResponses == 1)) / sum(sum(visCorrResponse == 1));
    vishitrate = rateadjust(vishitrate, numel(visResponses));
    visFArate = sum(sum(visCorrResponse == 2 & visResponses == 1)) / sum(sum(visCorrResponse == 2));
    visFArate = rateadjust(visFArate, numel(visResponses));
    dprime(s,1) = norminv(vishitrate) - norminv(visFArate);
    
    audhitrate = sum(sum(audCorrResponse == 1 & audResponses == 1)) / sum(sum(audCorrResponse == 1));
    audhitrate = rateadjust(audhitrate, numel(audResponses));
    audFArate = sum(sum(audCorrResponse == 2 & audResponses == 1)) / sum(sum(audCorrResponse == 2));
    audFArate = rateadjust(audFArate, numel(audResponses));
    dprime(s,2) = norminv(audhitrate) - norminv(audFArate);
    
end % subject loop

        