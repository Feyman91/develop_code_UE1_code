function [camped,toff,foff] = helperOFDMRxSearch(rxIn,sysParam)
%helperOFDMRxSearch Receiver search sequencer.
%   This helper function searches for the synchronization signal of the
%   base station to align the receiver timing to the transmitter timing.
%   Following successful detection of the sync signal, frequency offset
%   estimation is performed to on the first five frames to align the
%   receiver center frequency to the transmitter frequency.
%
%   Once this is completed, the receiver is declared camped and ready for
%   processing data frames. 
%
%   [camped,toff,foff] = helperOFDMRxSearch(rxIn,sysParam)
%   rxIn - input time-domain waveform
%   sysParam - structure of system parameters
%   camped - boolean to indicate receiver has detected sync signal and
%   estimated frequency offset
%   toff - timing offset as calculated from the sync signal location in
%   signal buffer
%   foff - frequency offset as calculated from the first 144 symbols
%   following sync symbol detection
%
% 获取当前基站的 ID
current_BS_id = sysParam.CrtRcv_DL_CoopBS_id;
fieldname = sprintf('DL_BS_%d', current_BS_id);

persistent syncDetected;
% 初始化 camped，如果为空
if isempty(syncDetected)
    syncDetected = struct();
end
% 如果该基站的状态还未存储，则初始化
if ~isfield(syncDetected, fieldname)
    syncDetected.(fieldname) = false;  % 初始化状态
end

% persistent syncDetected;
% if isempty(syncDetected)
%     syncDetected = false;
% end

% Create a countdown frame timer to wait for the frequency offset
% estimation algorithm to converge
persistent campedDelay;
% 初始化 camped，如果为空
if isempty(campedDelay)
    campedDelay = struct();
end
% 如果该基站的状态还未存储，则初始化
if ~isfield(campedDelay, fieldname)
    % The frequency offset algorithm requires 144 symbols to average before
    % the first valid frequency offset estimate. Wait a minimum number of
    % frames before declaring camped state.
    campedDelay.(fieldname) = ceil(144/sysParam.numSymPerFrame); 
end

% persistent campedDelay
% if isempty(campedDelay)
%     % The frequency offset algorithm requires 144 symbols to average before
%     % the first valid frequency offset estimate. Wait a minimum number of
%     % frames before declaring camped state.
%     campedDelay = ceil(144/sysParam.numSymPerFrame); 
% end

toff = [];  % by default, return an empty timing offset value to indicate
            % no sync symbol found or searched
camped = false;
foff = 0;

% Form the sync signal
% Step 1: Synchronization signal in BWP (relative index)
FFTLength = sysParam.FFTLen;
dcIdx = (FFTLength/2)+1;          
ZCsyncsignal_FD = helperOFDMSyncSignal(sysParam);
syncSignalIndRel = floor(sysParam.usedSubCarr / 2) - floor(length(ZCsyncsignal_FD) / 2) + (1:length(ZCsyncsignal_FD));  % Relative index in BWP
% Step 2: Calculate absolute index in total FFT based on BWP start index
syncSignalIndAbs = sysParam.subcarrier_start_index + syncSignalIndRel - 1;  % Absolute index in FFT grid
% Check if DC subcarrier index is included in syncSignalIndAbs, then drop that
if any(syncSignalIndAbs == dcIdx)
    % Adjust indices: for indices >= dcIdx, add 1 to avoid DC subcarrier
    syncSignalIndAbs(syncSignalIndAbs >= dcIdx) = syncSignalIndAbs(syncSignalIndAbs >= dcIdx) + 1;
end
syncNullInd = [1:(syncSignalIndAbs(1) - 1), (syncSignalIndAbs(end) + 1):FFTLength].';
% Step: Check if DC subcarrier is already in the null indices
if ~ismember(dcIdx, syncNullInd)
    syncNullInd = [syncNullInd; dcIdx];  % Include DC subcarrier only if it's not already in null indices
end
syncSignal = ofdmmod(ZCsyncsignal_FD,FFTLength,0,syncNullInd);

if ~syncDetected.(fieldname)
    % Perform timing synchronization
    toff = timingEstimate(rxIn,syncSignal,Threshold = 0.6);

    if ~isempty(toff)
        syncDetected.(fieldname) = true;
        toff = toff - sysParam.CPLen;
        fprintf('[%s]Sync symbol found.\n',fieldname);
        if sysParam.enableCFO
            fprintf('[%s]Estimating carrier frequency offset ...\n',fieldname);
        else
            camped = true; % go straight to camped if CFO not enabled
            fprintf('[%s]Receiver camped.\n',fieldname);
        end
    else
        syncDetected.(fieldname) = false;
        fprintf('.');
    end
else
    % Estimate frequency offset after finding sync symbol
    if campedDelay.(fieldname) > 0 && sysParam.enableCFO
        % Run the frequency offset estimator and start the averaging to
        % converge to the final estimate
        foff = helperOFDMFrequencyOffset(rxIn,sysParam);
        % fprintf('.');
        campedDelay.(fieldname) = campedDelay.(fieldname) - 1;
    else
        fprintf('[%s]Receiver camped.\n',fieldname);
        camped = true;
    end
end

end