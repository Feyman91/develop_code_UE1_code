function foffset = helperOFDMFrequencyOffset(rxWaveform,sysParam)
%helperOFDMFrequencyOffset Estimates frequency offset using cyclic prefix.
%   This function estimates the average frequency offset (foffset) using
%   the received time-domain waveform. The cyclic prefix portion of
%   the received time domain waveform is correlated with the end of the
%   symbol to estimate frequency offset. This correlation is averaged over
%   six symbols, and the maximum correlation angle is found and stored in a
%   buffer. 24 angles are averaged to result in the final CFO estimate.
%
%   foffset = helperOFDMFrequencyOffset(rxWaveform,sysParam) 
%   rxWaveform - input time-domain waveform
%   sysParam - system parameters structure
%   foffset - frequency offset is normalized to the symbol frequency. A value
%   of 1.0 is equal to the subcarrier spacing.



nFFT     = sysParam.FFTLen; 
cpLength = sysParam.CPLen;
symbLen  = nFFT + cpLength;
buffLen  = length(rxWaveform);

% 获取当前基站的 ID
current_BS_id = sysParam.CrtRcv_DL_CoopBS_id;
fieldname = sprintf('DL_BS_%d', current_BS_id);

numSymPerFrame = sysParam.numSymPerFrame;
numSampPerFrame = numSymPerFrame*symbLen;

% For per-frame processing, maintain last samples in an averaging buffer
persistent sampleAvgBuffer;
% 初始化 camped，如果为空
if isempty(sampleAvgBuffer)
    sampleAvgBuffer = struct();
end
% 如果该基站的状态还未存储，则初始化
if ~isfield(sampleAvgBuffer, fieldname)
    numFrames = floor(buffLen/numSampPerFrame);
    numAvgCols = ceil((150+numFrames)/6); % (24+1)*6 symbol minimum for averaging
    sampleAvgBuffer.(fieldname) = zeros(6*numAvgCols*symbLen,1);
end
% persistent sampleAvgBuffer;
% if isempty(sampleAvgBuffer)
%     numFrames = floor(buffLen/numSampPerFrame);
%     numAvgCols = ceil((150+numFrames)/6); % (24+1)*6 symbol minimum for averaging
%     sampleAvgBuffer = zeros(6*numAvgCols*symbLen,1);
% end

corrIn = [sampleAvgBuffer.(fieldname)(numSampPerFrame+1:end); rxWaveform];
sampleAvgBuffer.(fieldname) = corrIn;

% Form two correlator inputs, the second delayed from
% the first by nFFT.
arm1 = corrIn(1:end);
arm2 = [zeros(nFFT,1); corrIn(1:end-nFFT)];

% Conjugate multiply the inputs and integrate over the cyclic
% prefix length.
cpcorrunfilt = arm1.*conj(arm2);

cpcorrunfilt1 = cpcorrunfilt;
cpcorrunfilt2 = [zeros(cpLength,1); cpcorrunfilt(1:end-cpLength)];

cpCorr = cpcorrunfilt1-cpcorrunfilt2;
cpCorrFinal = cumsum(cpCorr)/cpLength;

% Perform Moving average filter of length 6
data = zeros(length(cpCorrFinal),6);
for ii = 1:6
    data(:,ii) = [zeros((ii-1)*symbLen,1); cpCorrFinal(1:end-(ii-1)*symbLen)];
end

avgCorr = sum(data,2)/6;

ObjMagOp   = abs(avgCorr);
ObjAngleOp = angle(avgCorr);
magOutput  = ObjMagOp;

% Divide the output angle by 2 to normalize
angleOutput = ObjAngleOp/(2*pi);

% Consider a window of 6 OFDM symbols
samplesfor6symbols = 6*symbLen;
maxOPNum = floor(length(magOutput)/samplesfor6symbols);

magOpReshape = reshape(magOutput(1:samplesfor6symbols*maxOPNum),samplesfor6symbols,maxOPNum);
angleOpReshape = reshape(angleOutput(1:samplesfor6symbols*maxOPNum),samplesfor6symbols,maxOPNum);

% Find max angle for every 6 OFDM symbols
maxMagOp = zeros(maxOPNum,1);
maxAngOp = zeros(maxOPNum,1);
for ii=1:maxOPNum
    [maxMagOp(ii),loc] = max(magOpReshape(:,ii));
    maxAngOp(ii) = angleOpReshape(loc,ii);
end

% Perform moving average filter of length 16
maxAngOpFinal = maxAngOp-[zeros(16,1); maxAngOp(1:end-16)];
foff = cumsum(maxAngOpFinal)/16;

% % Perform moving average filter of length 24
% maxAngOpFinal = maxAngOp-[zeros(24,1); maxAngOp(1:end-24)];
% foff = cumsum(maxAngOpFinal)/24;

% Repeat the values for every 6 OFDM symbols
cfoVal = ones(samplesfor6symbols,1)*[0;foff].';
cfoValFlat = cfoVal(:);

foffset = cfoValFlat(end-buffLen+1:end);

end
