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

% ********************注意！！！**********************
% 这里的minNumOfSymb_4CFOest和外部调用本函数的helperOFDMRxSearch保持完全的一致，要改都改。
% ********************注意！！！**********************
% 这里的minNumOfSymb_4CFOest值被用于sampleAvgBuffer长度的设定，其代表着被所有用于进行CFO估计的最小的symbol总数
% 根据测试和经验，其值越大，初始时第一次估计的CFO值就越稳定和准确。但导致缓存增加，程序计算量增加，耗费时间增多
% 这里最初example默认值取150
minNumOfSymb_4CFOest = 60; 

% movAvg_length_1st：该变量定义了第一次移动平均的窗口大小，即每次移动平均
% 操作所使用的 OFDM 符号的数量。较大的值将使结果更加平滑（减少噪声的影响），
% 但可能导致对快速频率变化的反应变慢。较小的值可以更快地跟踪频偏变化，
% 但估计结果可能更不稳定。这里最初example默认值为 6，意味着对 6 个符号进行移动平均。
movAvg_length_1st = 10;

% 这里的movAvg_length_2nd移动平均长度设定将被用于第二次（最后）输出的移动平均，
% 根据测试和经验，较大的值将使结果更加平滑（减少噪声的影响），估计的CFO越稳定，
% 但可能导致对快速频率变化的反应变慢。较小的值可以更快地跟踪频偏变化，但估计的CFO值会出现不稳定和跳变的情况。
% 这里最初example默认值取16，意味着对16个通过{movAvg_length_1st}个符号(默认为6个符号）移动平均计算出的频偏值再次进行移动平均
movAvg_length_2nd = 4;    

% 需要注意的是，movAvg_length_2nd 的取值需要综合考虑 movAvg_length_1st 和 minNumOfSymb_4CFOest。
% 在初始化缓冲区时，numAvgCols 的计算依赖于 minNumOfSymb_4CFOest 和 movAvg_length_1st，
% 它表示第1次移动平均操作所需的符号组数。为了保证移动平均操作的有效性，numAvgCols 应略大于
% 第二次移动平均长度 movAvg_length_2nd。
% 
% 比如，numAvgCols = ceil((minNumOfSymb_4CFOest + numFrames) / movAvg_length_1st)，
% 如果计算得 numAvgCols = ceil((60 + 1) / 10) = 7，那么选择 movAvg_length_2nd = 4 是合适的，
% 需要确保 movAvg_length_2nd 的值略小于numAvgCols。
% 
% 同时，movAvg_length_2nd 不应太接近 numAvgCols（比如不能选择6或7），否则可能导致 CFO 矫正不稳定或失效。
% 因此，在修改 movAvg_length_1st 或 minNumOfSymb_4CFOest 的值时，必须确保 movAvg_length_2nd 保持适当的比例关系，
% 这三个参数需要综合考虑，改变其中一个时应调整另一个以确保频偏估计的准确性和稳定性。

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
    numAvgCols = ceil((minNumOfSymb_4CFOest+numFrames)/movAvg_length_1st); % at least numAvgCols*movAvg_length_1st symbols minimum for averaging
    sampleAvgBuffer.(fieldname) = zeros(movAvg_length_1st*numAvgCols*symbLen,1);
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

% Perform Moving average filter of {1st_movAvg_length} symbol length
data = zeros(length(cpCorrFinal),movAvg_length_1st);
for ii = 1:movAvg_length_1st
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

avgCorr = sum(data,2)/movAvg_length_1st;

ObjMagOp   = abs(avgCorr);
ObjAngleOp = angle(avgCorr);
magOutput  = ObjMagOp;

% Divide the output angle by 2 to normalize
angleOutput = ObjAngleOp/(2*pi);

% Consider a window of {1st_movAvg_length} OFDM symbols
samples4_1stmovAvgLen_symbols = movAvg_length_1st*symbLen;
maxOPNum = floor(length(magOutput)/samples4_1stmovAvgLen_symbols);

magOpReshape = reshape(magOutput(1:samples4_1stmovAvgLen_symbols*maxOPNum),samples4_1stmovAvgLen_symbols,maxOPNum);
angleOpReshape = reshape(angleOutput(1:samples4_1stmovAvgLen_symbols*maxOPNum),samples4_1stmovAvgLen_symbols,maxOPNum);

% Find max angle for every group of {1st_movAvg_length} OFDM symbols
maxMagOp = zeros(maxOPNum,1);
maxAngOp = zeros(maxOPNum,1);
for ii=1:maxOPNum
    [maxMagOp(ii),loc] = max(magOpReshape(:,ii));
    maxAngOp(ii) = angleOpReshape(loc,ii);
end

% Perform moving average filter of length {movAvg_length_2nd}
maxAngOpFinal = maxAngOp-[zeros(movAvg_length_2nd,1); maxAngOp(1:end-movAvg_length_2nd)];
foff = cumsum(maxAngOpFinal)/movAvg_length_2nd;

% % Perform moving average filter of length 16
% maxAngOpFinal = maxAngOp-[zeros(16,1); maxAngOp(1:end-16)];
% foff = cumsum(maxAngOpFinal)/16;

% % Perform moving average filter of length 24
% maxAngOpFinal = maxAngOp-[zeros(24,1); maxAngOp(1:end-24)];
% foff = cumsum(maxAngOpFinal)/24;

% Repeat the values for every length of {1st_movAvg_length} OFDM symbols
cfoVal = ones(samples4_1stmovAvgLen_symbols,1)*foff.';
cfoValFlat = cfoVal(:);

foffset = cfoValFlat(end-buffLen+1:end);

end
