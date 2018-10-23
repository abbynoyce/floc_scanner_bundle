function floc_aud_test

% This function runs a few auditory stimuli from the floc task, to
% facilitate setting levels.

Screen('Preference','SkipSyncTests',1);

blocklength = 10; % 10 stimuli
cfg.timeoutTime = 1; % 1 second
cfg.ITI = .3; % 300 ms

% Pick files
cfg.aStimDir1 = ['animal-sounds' filesep 'cat_sounds' filesep];
cfg.aStimDir2 = ['animal-sounds' filesep 'dog_sounds' filesep];

d1 = dir([cfg.aStimDir1 '*.wav']);
for i = 1:numel(d1)
    d1(i).name = [cfg.aStimDir1 d1(i).name];
end
d2 = dir([cfg.aStimDir2 '*.wav']);
for i = 1:numel(d2)
    d2(i).name = [cfg.aStimDir2 d2(i).name];
end
d = [d1;d2];

allStims = Shuffle(d);
 while numel(allStims) < blocklength
     allStims = [allStims; Shuffle(d)];size(allStims)
 end  
 allStims = allStims(1:blocklength);
 
% PsychToolbox initializations
[cfg.win, rect] = Screen('OpenWindow',0,[0 0 0]);
cfg.freq = 44100; % Audio device frequency
InitializePsychSound;
cfg.pahandle = PsychPortAudio('Open', [], [], 0, cfg.freq,2);
    
% Squelch kb input, hide cursor.
ListenChar(2);
HideCursor;

Screen('TextSize', cfg.win, 36);
DrawFormattedText(cfg.win, '+', 'center','center',[255 255 255]);
[~, onset, ~, ~, ~] = Screen('Flip', cfg.win);

% Show stimuli
for t = 1:blocklength
    t
    datestr(now)
    fname = allStims(t).name;
    
    while GetSecs-onset < cfg.ITI
        % wait
    end
    
    audStim(cfg, fname);
    cfg.stimEndTime = GetSecs;
    
    while GetSecs - cfg.stimEndTime < cfg.timeoutTime
        % wait
    end
end

PsychPortAudio('Close', cfg.pahandle);
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
stim = wavread(file)';
stim = stim / max(max(stim)); % Normalize volume.
if size(stim,1) == 1
    stim = [stim;stim]; % make it stereo if it isn't already
end

% Playback
PsychPortAudio('FillBuffer', cfg.pahandle, stim);
PsychPortAudio('Start', cfg.pahandle, 1, 0, 1);
end