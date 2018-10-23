function floc_practice(subID, modality, run)
% This function runs a modality-specific (auditory or visual)
% working-memory task, and its passive-viewing equivalent, in
% alternating blocks
%
% Usage: floc(subID, modality, run)
%   subID: Subject identifier (string)
%   modality: Specifies sensory modality. 'a' auditory or 'v' visual
%   run: Each modality has two sets of stimuli, 1 or 2.

% TESTING
Screen('Preference', 'SkipSyncTests', 1);

% Numbers
blocklength = 32; % 30 images per block
% nBlocks = 4; A B B A
nBlocks = 1;
nback = 2;  % 2-back task
interval_ADDENDS = [1,1,2,2,3,4];
intervals = interval_ADDENDS + nback;

% Timing
cfg.timeoutTime = 1; % 1 second
cfg.ITI = .3; % 200 ms
TRlength = 2.6; % 2.6 seconds per TR;
TRperblock = 15;
cfg.blockTime = TRlength*TRperblock;
cfg.newBlockTime = TRlength*(TRperblock+2);

% Keys
cfg.repeatKey1 = '1';
cfg.repeatKey2 = '1!';
cfg.newKey1 = '2';
cfg.newKey2 = '2@';

% % Conditions for each block, different for scanner vs. behavioral version
% if condition == 1 % scanner version, has a passive condition
%     blockDetails = repmat([0 1 1], 1, ceil(nBlocks/3)); % 0 passive, 1 active
% elseif condition == 2 % behavioral version, only active conditions
     blockDetails = repmat([1 1], 1, ceil(nBlocks/2)); % 1 active
% end

% Specify stimuli locations and output locations
cfg.vStimDir1 = ['faces' filesep 'faces_female' filesep];
cfg.vStimDir2 = ['faces' filesep 'faces_male' filesep];
cfg.aStimDir1 = ['animal-sounds' filesep 'cat_sounds' filesep];
cfg.aStimDir2 = ['animal-sounds' filesep 'dog_sounds' filesep];
saveDir = ['results' filesep];

% Preallocate memory
stim = cell(blocklength,nBlocks);
responses = nan(blocklength,nBlocks,2);


filename = [subID datestr(now,'_yyyymmdd_HHMM') '.mat'];
% Create list of stimuli filenames
switch modality
    case 'a'
        modlabel = 'AUDITORY';
        if run == 1
            cfg.stimDir = cfg.aStimDir1;
        elseif run == 2
            cfg.stimDir = cfg.aStimDir2;
        end
        d = dir([cfg.stimDir '*.wav']);
        
    case 'v'
        modlabel = 'VISUAL';
        if run == 1
            cfg.stimDir =cfg.vStimDir1;
        elseif run == 2
            cfg.stimDir = cfg.vStimDir2;
        end
        d = dir([cfg.stimDir '*.bmp']);
end

save([saveDir filename]);

% PsychToolbox initializations
switch modality
    case 'a' % We only need audition for the auditory one.
        cfg.freq = 44100; % Audio device frequency
        InitializePsychSound;
        cfg.pahandle = PsychPortAudio('Open', [], [], 0, cfg.freq,2);
end
% We need Screen for both modalities.
% AssertOpenGL;
[cfg.win, rect] = Screen('OpenWindow',0,[0 0 0]);
cfg.win

% Squelch kb input, hide cursor.
ListenChar(2);
HideCursor;

% Make sure results directory exists
if ~exist(saveDir, 'dir')
    mkdir(saveDir)
end
save([saveDir filename]);

% Initialize a vector to tally number of n-backs for each block
% Initialize a matrix of 2s to store correct responses per trial per block (30x4)
num_repeats = 1:nBlocks;
corr_response = ones(length(1:blocklength),nBlocks)+1;

run_start_time = GetSecs;

for b = 1:nBlocks
    block_start_time = GetSecs;
    % Show block-type text.
    switch blockDetails(b)
        case 0
            text1 = sprintf('PASSIVE %s CONDITION', modlabel);
            text2 = 'Don''t forget to make keypresses';
        case 1
            text1 = sprintf('ACTIVE %s', modlabel);
            %text2 = 'Press "1" for repeat, "2" for new.';
            text2 = '';
    end
    
    Screen('TextSize', cfg.win, 36);
    DrawFormattedText(cfg.win, text1, 'center',(rect(4)/2 - 20),[255 255 255]);
    DrawFormattedText(cfg.win, text2, 'center',(rect(4)/2 + 20),[255 255 255]);
    Screen('Flip', cfg.win);
    WaitSecs(1.8);
    
    DrawFormattedText(cfg.win, '+', 'center','center',[255 255 255]);
    [~, onset, ~, ~, ~] = Screen('Flip', cfg.win);
    WaitSecs(0.8);
    
    % Pick stimuli. Get a list of stimuli, shuffle, pick 30.
    
    allStims = Shuffle(d);
    while numel(allStims) < blocklength
        allStims = [allStims; Shuffle(d)];
    end  %sorts through all the stimuli in the directory created above
    allStims = allStims(1:blocklength);  %selects 30 stimuli
    
    stimID = 1:blocklength; % Default to selecting each thing from allStims in order.
    
    switch blockDetails(b)
        case 0 % Passive block do nothing.
        case 1 % Active block create 2-backs.
            i = randsample(intervals,1);
            while i <= blocklength
                stimID(i) = stimID(i - nback);
                i = i + randsample(intervals,1);
            end
    end
    % Loop through stimID order per block, & save a correct response matrix
    % (1 if there is an n-back repeat, 2 if not)
    for c = 1:length(stimID)-nback
        if stimID(c) == stimID(c+nback)
            corr_response(c+nback,b) = 1;
        end
    end
    %Count how many n-backs there were in the stim set
    num_repeats(b) = length(find(corr_response(:,b) == 1));
    
    
    %% Show each stimulus
    for t = 1:blocklength
        if GetSecs-block_start_time > cfg.blockTime % Check to make sure we're still within blockTime
            break
        else
            fname = allStims(stimID(t)).name;
            stim{t,b} = fname;
            
            while GetSecs - onset < cfg.ITI
                % wait
            end
            
            % Present stimuli
            switch modality
                case 'a'
                    audStim(cfg,fname);
                    cfg.stimEndTime = GetSecs;
                case 'v'
                    visStim(cfg,fname);
                    cfg.stimEndTime = GetSecs;
            end
            
            responses(t,b,:) = getResponse(cfg); % This includes the long presentation of the visual stimuli
            Screen('TextSize', cfg.win, 36);
            DrawFormattedText(cfg.win, '+', 'center','center',[255 255 255]);
            
            while GetSecs - cfg.stimEndTime < cfg.timeoutTime
                % Even if the keypress happened early
                % Wait
            end
            [~, onset, ~, ~, ~] = Screen('Flip', cfg.win);
            
            if exist('imtex')
                Screen('Close',imtex);
            end
            
            WaitSecs(cfg.ITI);
        
        
            save([saveDir filename]);
        end
    end    
end

%Clean up: Let mouse and keyboard input happen again, close devices.
switch modality
    case 'a'
        PsychPortAudio('Close', cfg.pahandle);
end

ShowCursor;
ListenChar(0);
Screen('CloseAll');

end


function audStim(cfg,file)
% Loads and presents an auditory (wav) stimulus.

% Need to transpose, as audioread puts samples in rows and channels in
% columns, while PsychPortAudio wants the reverse.
% wavread is older function, used only for running on testing room Mac -
% otherwise change to audioread
stim = wavread([cfg.stimDir file])';
stim = stim / max(max(stim)); % Normalize volume.
if size(stim,1) == 1
    stim = [stim;stim]; % make it stereo if it isn't already
end

% Playback
PsychPortAudio('FillBuffer', cfg.pahandle, stim);
PsychPortAudio('Start', cfg.pahandle, 1, 0, 1);
end

function visStim(cfg,file)
% Loads and presents a visual (bmp) stimulus

stim = imread([cfg.stimDir file]);

imtex = Screen('MakeTexture', cfg.win, stim);
Screen('DrawTexture', cfg.win, imtex);
DrawFormattedText(cfg.win, '+', 'center','center',[0 0 0]);
Screen('Flip', cfg.win);

end

function responses = getResponse(cfg)

% This subfunction uses KbQueue to wait for participants to press a key; it
% checks whether it's a legal key and records the key and the time it was
% pressed.

responses = nan(1,1,2);

KbQueueCreate;
KbQueueStart;

% As long as it's before the timeout
while (GetSecs - cfg.stimEndTime < cfg.timeoutTime)
    % Look for keypresses
    [pressed, firstPress]=KbQueueCheck;
    % If a key is pressed
    if numel(find(firstPress)) == 1
        k = find(firstPress); % Keycode of pressed key
        if pressed && ismember(k, [KbName(cfg.repeatKey1) KbName(cfg.newKey1) KbName(cfg.repeatKey2) KbName(cfg.newKey2)])
            try
                switch k
                    case {KbName(cfg.repeatKey1), KbName(cfg.repeatKey2)}
                        r = 1;
                    case {KbName(cfg.newKey1), KbName(cfg.newKey2)}
                        r = 2;
                end
                responses(1,1,1) = r;
                responses(1,1,2) = firstPress(k) - cfg.stimEndTime;
                break
            catch
                'KbQueue failure'
                break
            end
        end
    else
        % Multiple keys pressed
        responses(1,1,1) = -999;
        responses(1,1,2) = -999;
    end
end

KbQueueRelease;

% Timeout.
if GetSecs - cfg.stimEndTime > cfg.timeoutTime
    responses(1,1,1) = 999;
    responses(1,1,2) = 999;
end

end

