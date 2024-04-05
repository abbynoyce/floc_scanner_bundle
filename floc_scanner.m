
function floc_scanner(subID, whichorder, device)
% This function runs a modality-specific (auditory or visual)
% working-memory task, and its passive-viewing equivalent, in
% alternating blocks
%
% Usage: floc(subID, blockorder, device)
%   subID: Subject identifier (string, 2 characters)
%   whichorder: 1,2,3, or 4. Describes which order the 8 blocks occur in.
%   whichorder: 7 (auditory first, then alternating) or 8 (visual first) for all-active runs.
%   device: 'scanner' or 'laptop'. Specifies which keyboard to listen on
%   for input.
%
% 180 TRs.



%% Specify params

% Setup
cfg.kb = getKeyboardID(device)
switch device
    case 'scanner'
        Screen('Preference', 'SkipSyncTests', 1);
        cfg.screen = 0;
        cfg.eyetracker = 1;
    case 'laptop'
        % TESTING/PRACTICE
        Screen('Preference', 'SkipSyncTests', 1);
        cfg.screen = 0;
        cfg.eyetracker = 0;
    case 'bridgemac'
        % TESTING
        Screen('Preference', 'SkipSyncTests', 1);
        cfg.screen = 1;
        %cfg.eyetracker = 1;
        cfg.eyetracker = 0;
end

% Filenames
order_file = 'blockorder';

cfg.vStimDir1 = ['faces' filesep 'faces_female' filesep];
cfg.vStimDir2 = ['faces' filesep 'faces_male' filesep];
cfg.aStimDir1 = ['animal-sounds' filesep 'cat_sounds' filesep];
cfg.aStimDir2 = ['animal-sounds' filesep 'dog_sounds' filesep];
saveDir = ['results' filesep];

% Numbers
blocklength = 32; % 32 images per block
nback = 2;  % 2-back task
interval_ADDENDS = [1,1,2,2,3,4];
intervals = interval_ADDENDS + nback;

% Timing
cfg.timeoutTime = 1; % 1 second per item.
TR = 2; % 2 seconds per TR
%TR = 2.6; % 2.6 seconds per TR;
TRperblock = 21; % 32 images in 40 seconds, plus 1 for start-of-block instructions
cfg.blockTime = TR*TRperblock;

% Keys
cfg.repeatKey1 = '1';
cfg.repeatKey2 = '1!';
cfg.newKey1 = '2';
cfg.newKey2 = '2@';
cfg.triggerKey1 = '=';
cfg.triggerKey2 = '=+';

% Get block details specifications
f = fopen(order_file);
a = textscan(f, '%s %s %s %s %s %s');
order = a{whichorder}; 
% order is a nblocks x 1 cell array. Each cell is a three-letter string, 
% 'ACP', 'VMA', etc. First letter specifies modality, second letter
% specifies stimulus set, third letter specifies active/passive
nBlocks = size(order,1);

% Preallocate memory
responses = nan(blocklength,nBlocks,2);
cfg.stim_presented = cell(blocklength, nBlocks);
filename = [subID datestr(now,'_yyyymmdd_HHMM') '.mat'];
edf_filename = [subID datestr(now, 'HHMM') '.edf'];

save([saveDir filename]);

%% PsychToolbox initializations

cfg.freq = 44100; % Audio device frequency
InitializePsychSound;
cfg.pahandle = PsychPortAudio('Open', 2, [], 0, cfg.freq,2);

AssertOpenGL;
[cfg.win, rect] = Screen('OpenWindow',cfg.screen,[0 0 0]);
if cfg.eyetracker
    cfg.vDistance = 107.5; % scanner viewing distance w/ eyetracker
    cfg.dWidth = 41.5; % scanner display width w/ eyetracker
    ppd = pi*rect(3) / atan(cfg.dWidth/cfg.vDistance/2) / 360;
end

% Squelch kb input, hide cursor.
 ListenChar(2);
% HideCursor;

%% Initialize and save
% Make sure results directory exists
if ~exist(saveDir, 'dir')
    mkdir(saveDir)
end
save([saveDir filename]);

% Initialize a vector to tally number of n-backs for each block
% Initialize a matrix of 2s to store correct responses per trial per block (30x4)
num_repeats = 1:nBlocks;
corr_response = ones(length(1:blocklength),nBlocks)+1;

% Set up timing parameters
% This is all very hand-coded for 8 blocks, 4 TRs of fixation at beginning,
% middle, end of run, 1 TR of instructions, etc.
block_starts = ([0:7] * TR * TRperblock) + 4*TR; % Timepoints at which each block needs to start. 
block_starts(5:8) = block_starts(5:8) + 4*TR; % Plus 4 TRs of fixation at mid-run.
block_landmarks = TR*cumsum([0 1 .625*ones(1,blocklength)]); % 1 TR instructions, .625 TR per trial

%%
% -------------
% Eyelink setup
% -------------

if cfg.eyetracker
    
    % set "width" and "height"
    width = rect(3);
    height = rect(4);
    
    % Initialize
    el = EyelinkInitDefaults(cfg.win);
    
    % Set display colors
    el.backgroundcolour = [0,0,0];
    el.foregroundcolour = [100 100 100];
    el.calibrationtargetcolour = [255,255,255];
    
    EyelinkUpdateDefaults(el); % Apply the changes set above.
    
    % Check it came up.
    if ~EyelinkInit(0)
        fprintf('Eyelink Init aborted.\n');
        Eyelink('Shutdown');
        return;
    end
    
    % Sanity check connection
    connected = Eyelink('IsConnected')
    [~, vs] = Eyelink('GetTrackerVersion');
    fprintf('Running experiment on a ''%s'' tracker.\n', vs);
    
    % open file to record tracker data
    tempeyefile = Eyelink('Openfile', edf_filename);
    if tempeyefile ~= 0
        fprintf('Cannot create EDF file ''%s'' ', edf_filename);
        Eyelink('Shutdown');
        return;
    end
    
    % Host PC parameters
    Eyelink('command', 'screen_pixel_coords = %ld %ld %ld %ld', 0, 0, rect(3)-1, rect(4)-1); % 0,0,width,height
    Eyelink('message', 'DISPLAY_COORDS %ld %ld %ld %ld', 0, 0, rect(3)-1, rect(4)-1);
    
    % 9-target calibration - specify target locations.
    Eyelink('command', 'calibration_type = HV9');
    Eyelink('command', 'generate_default_targets = NO');
    
    caloffset=round(4.5*ppd);
    Eyelink('command','calibration_samples = 10');
    Eyelink('command','calibration_sequence = 0,1,2,3,4,5,6,7,8,9');
    Eyelink('command','calibration_targets = %d,%d %d,%d %d,%d %d,%d %d,%d %d,%d %d,%d %d,%d %d,%d',...
        round(width/2),round(height/2),  round(width/2),round(height/2)-caloffset,  round(width/2),round(height/2) + caloffset,  round(width/2) -caloffset,round(height/2),  round(width/2) +caloffset,round(height/2),...
        round(width/2)-caloffset, round(height/2)- caloffset, round(width/2)-caloffset, round(height/2)+ caloffset, round(width/2)+caloffset, round(height/2)- caloffset, round(width/2)+caloffset, round(height/2)+ caloffset);
    Eyelink('command','validation_samples = 9');
    Eyelink('command','validation_sequence = 0,1,2,3,4,5,6,7,8,9');
    Eyelink('command','validation_targets = %d,%d %d,%d %d,%d %d,%d %d,%d %d,%d %d,%d %d,%d %d,%d',...
        round(width/2),round(height/2),  round(width/2),round(height/2)-caloffset,  round(width/2),round(height/2) + caloffset,  round(width/2) -caloffset,round(height/2),...
        round(width/2) +caloffset,round(height/2),...
        round(width/2)-caloffset, round(height/2)- caloffset, round(width/2)-caloffset, round(height/2)+ caloffset, round(width/2)+caloffset, round(height/2)- caloffset, round(width/2)+caloffset, round(height/2)+ caloffset);
    
    % Set lots of criteria
    Eyelink('command', 'saccade_acceleration_threshold = 8000');
    Eyelink('command', 'saccade_velocity_threshold = 30');
    Eyelink('command', 'saccade_motion_threshold = 0.0');
    Eyelink('command', 'saccade_pursuit_fixup = 60');
    Eyelink('command', 'fixation_update_interval = 0');
    
    % set EDF file contents
    Eyelink('command', 'file_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON');
    Eyelink('command', 'file_sample_data  = LEFT,RIGHT,GAZE,HREF,AREA,GAZERES,STATUS');
    
    % set link data (used for gaze cursor)
    Eyelink('command', 'link_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON');
    Eyelink('command', 'link_sample_data  = LEFT,RIGHT,GAZE,GAZERES,AREA,STATUS');
    
    % make sure we're still connected.
    if Eyelink('IsConnected')~=1
        Eyelink( 'Shutdown');
        return;
    end
    
    % Initial calibration of the eye tracker
    EyelinkDoTrackerSetup(el);
    eye_used = Eyelink('EyeAvailable');
    
end


%% Start experiment

% Alert.
% if strcmp(device,'scanner')
    Screen('TextSize', cfg.win, 36);
    DrawFormattedText(cfg.win, 'Waiting for scanner.', 'center','center',[255 255 255]);
    Screen('Flip', cfg.win);
% end
    
run_start_time = getTrigger(cfg);
%run_start_time = GetSecs;

% Fixation at start of run.
Screen('TextSize', cfg.win, 36);
DrawFormattedText(cfg.win, '+', 'center','center',[255 255 255]);
Screen('Flip', cfg.win);
'Start-run fixation'
 j = 1; % SANITY CHECK TEST

for b = 1:nBlocks
    %b
    %% Block setup stuff
    
    % Parse order
    thisblock = order{b}
    modality = thisblock(1);
    stim = thisblock(2);
    task = thisblock(3);
    
    % Create list of stimuli filenames
    switch modality
        case {'a','A'}
            switch stim
                case 'C'
                    cfg.stimDir = cfg.aStimDir1;
                case 'D'
                    cfg.stimDir = cfg.aStimDir2;
            end
            d = dir([cfg.stimDir '*.wav']);
            modlabel = 'AUDITORY';
             
        case {'v','V'}
            switch stim
                case 'W'
                    cfg.stimDir = cfg.vStimDir1;
                case 'M'
                    cfg.stimDir =  cfg.vStimDir2;
            end
            d = dir([cfg.stimDir '*.bmp']);
            modlabel = 'VISUAL';
    end
    
    % Pick stimuli. Get a list of stimuli, shuffle, pick 32.
    allStims = Shuffle(d);
    while numel(allStims) < blocklength
        allStims = [allStims; Shuffle(d)];
    end
    allStims = allStims(1:blocklength);  %selects 32 stimuli
    
    stimID = 1:blocklength; % Default to selecting each thing from allStims in order.
    
    switch task
        case 'P' % Passive block do nothing.
        case 'A' % Active block create 2-backs.
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
    
    % -------------
    % Eyelink Stuff
    % -------------
    if cfg.eyetracker
        % Must be offline to draw to EyeLink screen
        Eyelink('Command', 'set_idle_mode');
        
        % clear tracker display and draw box at fix point
        box = round(2.5*ppd);
        Eyelink('Command', 'clear_screen 0')
        Eyelink('command', 'draw_box %d %d %d %d 15', (width/2)-box, (height/2)-box, (width/2)+box, (height/2)+box);
        
        Eyelink('Command', 'set_idle_mode');
    end
    % -------------
    
    %% Run block
    % Show block-type text.
    switch task
        case 'P'
            text1 = sprintf('PASSIVE %s', modlabel);
            text2 = '';
        case 'A'
            text1 = sprintf('ACTIVE %s ', modlabel);
            text2 = '';
    end
    
    Screen('TextSize', cfg.win, 36);
    DrawFormattedText(cfg.win, text1, 'center',(rect(4)/2 - 20),[255 255 255]);
    DrawFormattedText(cfg.win, text2, 'center',(rect(4)/2 + 20),[255 255 255]);
    
    while GetSecs-run_start_time < block_starts(b)
        %'waiting!'
        % wait
    end
    'Before block:'
    GetSecs - run_start_time
    Screen('Flip', cfg.win);
    
    % ----------------
    % Eyelink Stuff
    % ----------------
    if cfg.eyetracker
        Eyelink('command', 'record_status_message "BLOCK %d"', b);
        Eyelink('StartRecording');
    end
    % ---------------
    
    WaitSecs(1.4);
    
    % ----------------
    % Eyelink Stuff
    % ----------------
    if cfg.eyetracker
        Eyelink('Message','SYNCTIME');
    end
    % ---------------
    
    DrawFormattedText(cfg.win, '+', 'center','center',[255 255 255]);
    Screen('Flip', cfg.win);
    
    % Show each stimulus
    for t = 1:blocklength
        t
        if GetSecs - block_starts(b) - run_start_time > cfg.blockTime % Check to make sure we're still within blockTime
            break
        else
            fname = allStims(stimID(t)).name;
            cfg.stim_presented{t,b} = fname;

            while GetSecs - block_starts(b) - run_start_time < block_landmarks(t+1)
                %wait
            end
%             % SANITY CHECK TEST TIMING
%             time(j) = GetSecs - run_start_time;
%             if j > 1
%                 time(j) - time(j-1)
%             end
%             j = j+1;
            
            % -------------
            % Eyelink Stuff
            % -------------
            if cfg.eyetracker
                Eyelink('Message','SYNCTIME');
            end
            % ------------
            
            % Present stimuli
            switch modality
                case {'a', 'A'}
                    audStim(cfg,fname);
                    cfg.stimEndTime = GetSecs;
                case {'v','V'}
                    visStim(cfg,fname);
                    cfg.stimEndTime = GetSecs;
            end
            
            responses(t,b,:) = getResponse(cfg); % This includes the long presentation of the visual stimuli
            Screen('TextSize', cfg.win, 36);
            
            while GetSecs - cfg.stimEndTime < cfg.timeoutTime
                % wait
            end
            
            DrawFormattedText(cfg.win, '+', 'center','center',[255 255 255]);
            Screen('Flip', cfg.win);
            
            save([saveDir filename]);
        end
        
    end
    'end of block'
    b
    GetSecs - run_start_time
    
end

while GetSecs - run_start_time < block_starts(b) + cfg.blockTime + 4*TR
    % waiting = '4TR wait for end-run fixation'
end

if cfg.eyetracker
    Eyelink('StopRecording');
    Eyelink('Message','TRIAL_RESULT 0');
end

run_end_time = GetSecs - run_start_time
save([saveDir filename]);

%Clean up: Let mouse and keyboard input happen again, close devices.

% --------------
% Eyelink Stuff
% --------------
if cfg.eyetracker
     Eyelink('Command', 'set_idle_mode');
     WaitSecs(0.5);
     Eyelink('CloseFile');
     % download data file
     
     try
         fprintf('Receiving data file ''%s''\n', edf_filename );
         status=Eyelink('ReceiveFile');
         if status > 0
             fprintf('ReceiveFile status %d\n', status);
         end
         if 2==exist(edf_filename, 'file')
             fprintf('Data file ''%s'' can be found in ''%s''\n', edf_filename, pwd );
         end
     catch
         fprintf('Problem receiving data file ''%s''\n', edf_filename );
     end
     %%%%%%%%%%%%%%%%shut it down
     Eyelink('ShutDown');
end
% -------------

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
stim = audioread([cfg.stimDir file])';
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
Screen('Close',imtex); % Close textire after presenting it

end

function responses = getResponse(cfg)

% This subfunction uses KbQueue to wait for participants to press a key; it
% checks whether it's a legal key and records the key and the time it was
% pressed.

responses = nan(1,1,2);

KbQueueCreate(cfg.kb);
KbQueueStart(cfg.kb);

% As long as it's before the timeout
while (GetSecs - cfg.stimEndTime < cfg.timeoutTime)
    % Look for keypresses
    [pressed, firstPress]=KbQueueCheck(cfg.kb);
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
        elseif ismember(k, [KbName('3'),KbName('3#'), KbName('4'),KbName('4$')])
            responses(1,1,1) = k;
            responses(1,1,2) = firstPress(k) - cfg.stimEndTime;
        end
    else
        % Multiple keys pressed
        responses(1,1,1) = -999;
        responses(1,1,2) = -999;
    end
end

KbQueueRelease(cfg.kb);

% Timeout.
if GetSecs - cfg.stimEndTime > cfg.timeoutTime
    responses(1,1,1) = 999;
    responses(1,1,2) = 999;
end

end

function run_start_time = getTrigger(cfg)

% This subfunction uses KbQueue to wait for participants to press a key; it
% checks whether it's a legal key and records the key and the time it was
% pressed.

KbQueueCreate(cfg.kb);
KbQueueStart(cfg.kb);

while 1
    % Look for keypresses
    [pressed, firstPress]=KbQueueCheck(cfg.kb);
    if find(firstPress)
        find(firstPress)
    end
    % If a key is pressed
    if numel(find(firstPress)) == 1
        k = find(firstPress); % Keycode of pressed key
        if pressed && ismember(k, [KbName(cfg.triggerKey1) KbName(cfg.triggerKey2)])
            try
                run_start_time = firstPress(k)
                break
            catch
                'KbQueue failure'
                run_start_time = GetSecs;
                break
            end
        end
        
    end
end

KbQueueRelease(cfg.kb);

end

function kbnum = getKeyboardID(device)

% Which string to look for?
switch device
    case 'scanner'
        devstring = 'Celeritas Dev';
    case 'laptop'
        devstring = 'Apple Internal Keyboard / Trackpad';
    case 'bridgemac'
        devstring = 'USB Device';
end

[id,name] = GetKeyboardIndices;

kbnum = 0;
for i = 1:numel(id)
    if strcmp(name{i}, devstring)
        kbnum = id(i);
        break
    end
end

if kbnum==0 % error checking
    error('No device by that name was detected');
end

end

