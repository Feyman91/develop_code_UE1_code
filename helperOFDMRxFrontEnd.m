function rxOut = helperOFDMRxFrontEnd(rxIn,sysParam,rxObj,spectrumAnalyze, watchFilterdResult)
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

% 获取当前基站的 ID
current_BS_id = sysParam.CrtRcv_DL_CoopBS_id;
fieldname = sprintf('DL_BS_%d', current_BS_id);
symLen = (sysParam.FFTLen+sysParam.CPLen);
frameLen = symLen * sysParam.numSymPerFrame;

% Create a set of persistent signal buffer to simulate the asynchronousity between
% the transmitter and receiver signal timing, and set difference between
% each cooperrative Base station
persistent signalBuffers;

% 初始化 signalBuffers，如果为空
if isempty(signalBuffers)
    signalBuffers = struct();
end

% 如果该基站的状态还未存储，则初始化
if ~isfield(signalBuffers, fieldname)
    signalBuffers.(fieldname) = zeros(2*frameLen+2*symLen,1);  % 初始化状态
end
% if isempty(signalBuffers)
%     signalBuffers = zeros(2*frameLen+2*symLen,1);
% end

% Perform filtering
rxFiltered = rxObj.rxFilter(rxIn);
if watchFilterdResult
    spectrumAnalyze(rxFiltered);
end
% Enter signal into buffer and perform timing adjustment
signalBuffers.(fieldname) = [signalBuffers.(fieldname)(frameLen+(1:frameLen)); rxFiltered; zeros(symLen*2,1)];
timingAdvance = sysParam.timingAdvance;
rxOut = signalBuffers.(fieldname)(timingAdvance+(1:frameLen+2*symLen)); % output one frame plus the sync and ref symbol of the next frame

end