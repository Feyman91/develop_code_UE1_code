function rxOut = helperOFDMRxFrontEnd(rxIn,sysParam,rxObj)
%helperOFDMRxFrontEnd Receiver front-end processing
%   This helper function handles sample buffer management and front-end
%   filtering. This simulates a typical receiver front end component. 
%
%   Optional components such as AGC and A/D converters may also be added to
%   this helper function for more detailed simulations.
%
%   rxOut = helperOFDMRxFrontEnd(rxIn,sysParam,rxObj)
%   rxIn - input time-domain waveform
%   sysParam - structure of system parameters
%   rxObj - structure of rx states and parameters
%

% Copyright 2023 The MathWorks, Inc.

symLen = (sysParam.FFTLen+sysParam.CPLen);
frameLen = symLen * sysParam.numSymPerFrame;

% Create a persistent signal buffer to simulate the asynchronousity between
% the transmitter and receiver signal timing
persistent signalBuffer;
if isempty(signalBuffer)
    signalBuffer = zeros(2*frameLen+2*symLen,1);
end

% Perform filtering
rxFiltered = rxObj.rxFilter(rxIn);

% Enter signal into buffer and perform timing adjustment
signalBuffer = [signalBuffer(frameLen+(1:frameLen)); rxFiltered; zeros(symLen*2,1)];
timingAdvance = sysParam.timingAdvance;
rxOut = signalBuffer(timingAdvance+(1:frameLen+2*symLen)); % output one frame plus the sync and ref symbol of the next frame

end