function newrate = rateadjust(rate, nTrials)

% This support function adjusts hit and FA rates to be neither 1 nor zero.
%
% Abigail Noyce, January 2015

if rate == 1
    newrate = 1 - (0.5/nTrials);
elseif rate == 0
    newrate = 0.5/nTrials;
else newrate = rate;
end