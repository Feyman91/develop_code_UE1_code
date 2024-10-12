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

% 下面的两个参数可以动态调整以提高CFO估计的准确性
% 这里的movAvg_length移动平均长度设定将被用于最后输出的移动平均，
% 根据测试和经验，其值越大，估计的越稳定，CFO矫正越出色。但导致程序计算量增加，耗费时间增多
% 这里最初example默认值取16
movAvg_length = 6;          
% 这里的minNumOfSymb_4CFOest值被用于sampleAvgBuffer长度的设定，其代表着被所有用于进行CFO估计的最小的symbol总数
% 根据测试和经验，其值越大，估计的越稳定，CFO矫正越出色。但导致缓存增加，程序计算量增加，耗费时间增多
% 这里最初example默认值取150
minNumOfSymb_4CFOest = 60; 

% 需要注意的是，下面初始化buffer中国根据minNumOfSymb_4CFOest计算得到numAvgCols，需要略大于movAvg_length
% 比如numAvgCols = ceil((60+numFrames)/6) = 11；那么movAvg_length = 6＜11是正确的，
% 同时这里movAvg_length也不能太过于接近numAvgCols，比如movAvg_length不能取9 or 10，否则就会导致CFO矫正出现问题
% 因此改变上面两个参数的时候需要同时兼顾并动态调整，改1个则要注意另一个


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
    numAvgCols = ceil((minNumOfSymb_4CFOest+numFrames)/6); % (minNumOfSymb_4CFOest+1)*6 symbol minimum for averaging
    sampleAvgBuffer.(fieldname) = zeros(6*numAvgCols*symbLen,1);
end
% persistent sampleAvgBuffer;
% if isempty(sampleAvgBuffer)
%     numFrames = floor(buffLen/numSampPerFrame);
%     numAvgCols = ceil((150+numFrames)/6); % (24+1)*6 symbol minimum for averaging
%     sampleAvgBuffer = zeros(6*numAvgCols*symbLen,1);
% end

corrIn = [sampleAvgBuffer.(fieldname)(buffLen+1:end); rxWaveform];
% corrIn = [sampleAvgBuffer.(fieldname)(numSampPerFrame+1:end); rxWaveform];
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

% Perform Moving average filter of 6 symbol length
data = zeros(length(cpCorrFinal),6);
for ii = 1:6
    data(:,ii) = [zeros((ii-1)*symbLen,1); cpCorrFinal(1:end-(ii-1)*symbLen)];
end

% % this is test code for angle only average 
% angle_corr1 = angle(cpcorrunfilt);
% angle_corr2 = [zeros(cpLength,1); angle_corr1(1:end-cpLength)];
% 
% angle_cpcorr = angle_corr1 - angle_corr2;
% angle_cpCorrFinal = cumsum(angle_cpcorr)/cpLength;
% 
% angle_data = zeros(length(angle_cpCorrFinal),6);
% for ii = 1:6
%     angle_data(:,ii) = [zeros((ii-1)*symbLen,1); angle_cpCorrFinal(1:end-(ii-1)*symbLen)];
% end
% 
% angle_avgCorr = sum(angle_data,2)/6;
% 
% % Divide the output angle by 2 to normalize
% angleOutput = angle_avgCorr/(2*pi);
% % this is end of test code for angle only average 

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

% Perform moving average filter of length {movAvg_length}
maxAngOpFinal = maxAngOp-[zeros(movAvg_length,1); maxAngOp(1:end-movAvg_length)];
foff = cumsum(maxAngOpFinal)/movAvg_length;

% % Perform moving average filter of length 16
% maxAngOpFinal = maxAngOp-[zeros(16,1); maxAngOp(1:end-16)];
% foff = cumsum(maxAngOpFinal)/16;

% % Perform moving average filter of length 24
% maxAngOpFinal = maxAngOp-[zeros(24,1); maxAngOp(1:end-24)];
% foff = cumsum(maxAngOpFinal)/24;

% Repeat the values for every 6 OFDM symbols
cfoVal = ones(samplesfor6symbols,1)*[0;foff].';
cfoValFlat = cfoVal(:);

foffset = cfoValFlat(end-buffLen+1:end);

end
