function [rxDataBits,isConnected,toff,diagnostics] = helperOFDMRx(rxWaveform,sysParam,rxObj,timesink)
%helperOFDMRx Processes OFDM signal.
%   Performs carrier frequency offset estimation and correction, frame
%   synchronization, OFDM demodulation, channel estimation, channel
%   equalization, phase offset correction, and decodes transmitted bits.
%
%   [rxDataBits,isConnected,toff,diagnostics] = helperOFDMRx(rxWaveform,sysParam,rxObj)
%   rxWaveform - input time-domain waveform
%   sysParam - structure of system parameters
%   rxObj - structure of rx parameters and states
%   rxDataBits  - Decoded information bits
%   isConnected - indicates if the receiver is in a connected state
%   toff - timing offset desired from receiver
%   diagnostics - Struct that contains:
%    estCfo                - Values of estimated carrier frequency 
%                            offset for entire frame
%    estChannel            - Values of estimated channel for entire frame
%    timeOffset            - Time offset values
%    rxConstellationHeader - Demodulated constellation symbols of
%                            header
%    rxConstellationData   - Demodulated constellation symbols of
%                            transmitted data information
%    softLLR               - LLR values (soft information) of symbol
%                            demodulated data
%    decodedCodeRateIndex  - Decoded code rate from header
%    decodedModRate        - Decoded modulation order from header
%    headerCRCErrorFlag    - Indicates header CRC status (0-pass, 1-fail)
%    dataCRCErrorFlag      - Indicates data CRC status (0-pass, 1-fail)
 
%   Copyright 2023-2024 The MathWorks, Inc.

persistent camped;
if isempty(camped)
    camped = false;
end

persistent rxInternalDiags;
if isempty(rxInternalDiags)
    rxInternalDiags = struct( ...
        'estCFO',[],...
        'estChannel',[],...
        'dataCRCErrorFlag',[]);
end

if ~camped
    isConnected = false;
    rxDataBits = [];
    % Search for sync symbol
    [camped,ta,foff] = helperOFDMRxSearch(rxWaveform,sysParam);
    if ~camped
        diagnostics.estCFO = foff;
    else
        diagnostics.estCFO = [];
    end
    diagnostics.dataCRCErrorFlag = [];
    diagnostics.estChannel = [];
    
    % If ta is not empty, sync symbol was found. Adjust buffer timing so that
    % the sample buffer starts at the sync symbol
    if ~isempty(ta)
        % Sync symbol found
        % toff = ta + 1;
        toff = ta;
    else
        toff = sysParam.timingAdvance;
    end
else
    % Receiver is camped on the base station
    isConnected = true;
    toff = sysParam.timingAdvance;

    if sysParam.verbosity > 0
        fprintf('Detected and processing frame %d\n', sysParam.frameNum);
        fprintf('------------------------------------------\n');
    else
        fprintf('.');
        if floor(sysParam.frameNum/80) == sysParam.frameNum/80
            fprintf('\n');
        end
    end

    % Run frame processing
    [rxDataBits,diagnostics] = rxFrame(rxWaveform,sysParam,rxObj,timesink);
end

% Collect diagnostics
oldCFO = rxInternalDiags.estCFO;
oldFrameError = rxInternalDiags.dataCRCErrorFlag;
oldEstChannel = rxInternalDiags.estChannel;
rxInternalDiags = diagnostics;
if sysParam.frameNum < 40
    rxInternalDiags.estCFO = [oldCFO; diagnostics.estCFO];
    rxInternalDiags.estChannel = [oldEstChannel; diagnostics.estChannel];
end
rxInternalDiags.dataCRCErrorFlag = [oldFrameError; diagnostics.dataCRCErrorFlag];

diagnostics = rxInternalDiags;

end

function [rxDataBits,diagnostics] = rxFrame(rxWaveform,sysParam,rxObj,timesink)

% Define reference signal, pilot signal, and parameters
ssIdx           = sysParam.ssIdx;        % sync symbol index
rsIdx           = sysParam.rsIdx;        % reference symbol index
headerIdx       = sysParam.headerIdx;    % header symbol index
FFTLength       = sysParam.FFTLen;
CPLength        = sysParam.CPLen;
usedSubCarr     = sysParam.usedSubCarr;
pilotSpacing    = sysParam.pilotSpacing;
pilotsPerSym    = sysParam.pilotsPerSym;
channelEstRefSymbols = helperOFDMRefSignal(usedSubCarr);
pilotSignal     = helperOFDMPilotSignal(pilotsPerSym);
numSymPerFrame  = sysParam.numSymPerFrame;
verbosity       = sysParam.verbosity;

frameLength     = (FFTLength + CPLength)*numSymPerFrame; % total number of samples in one frame
numSampPerSym   = FFTLength + CPLength;
shortFrameLength = frameLength - numSampPerSym; % total samples in a frame without the sync symbol
nullIdx = [1:((FFTLength-usedSubCarr)/2) ...
    (FFTLength/2)+1 ...
    ((FFTLength+usedSubCarr)/2)+2:FFTLength]';
dataIdx = setdiff(1:usedSubCarr,1:pilotSpacing:usedSubCarr);
cpFraction = 0.55;
symbOffset = ceil(cpFraction*CPLength);
syncSigLen = numSampPerSym;

% Perform frequency offset estimation and correction
if sysParam.enableCFO
    if verbosity > 0
        fprintf('Estimating carrier frequency offset ... \n');
    end
    freqOffset = helperOFDMFrequencyOffset(rxWaveform,sysParam);
    rxObj.freqOffset = freqOffset;
    if verbosity > 0
        fprintf('Estimated carrier frequency offset is %d Hz.\n', ...
            freqOffset(end) * sysParam.scs);
    end
    if verbosity > 0
        fprintf('Correcting frequency offset across all samples\n');
    end
    cfoCorrectedData = rxObj.pfo( ...
        rxWaveform,-freqOffset(1:length(rxWaveform))*sysParam.scs);
    if sysParam.enableTimescope
        timesink([real(rxWaveform),imag(rxWaveform)],[real(cfoCorrectedData),imag(cfoCorrectedData)])
    end
else
    freqOffset = zeros(length(rxWaveform),1);
    cfoCorrectedData = rxWaveform;
end

% Define output parameters
softLLRs        = [];
dataConstData   = zeros(usedSubCarr-pilotsPerSym,...
    numSymPerFrame-length(ssIdx)-length(rsIdx)-length(headerIdx));

%% Perform OFDM demodulation, header decoding, and data decoding per frame

% Extract out the header and data samples
dataHeaderFrame = cfoCorrectedData(syncSigLen+(1:shortFrameLength));

% Extract out the reference symbol samples and demod
refSamples = cfoCorrectedData(syncSigLen+(1:numSampPerSym));
demodulatedRS = ofdmdemod(refSamples,FFTLength,CPLength,symbOffset,nullIdx);

% Extract out the next reference symbol samples and demod
refSamples = cfoCorrectedData(frameLength+syncSigLen+(1:numSampPerSym));
demodulatedNextRS = ofdmdemod(refSamples,FFTLength,CPLength,symbOffset,nullIdx);

% Perform channel estimation over all subcarriers and symbols in the
% frame
estChannel = helperOFDMChannelEstimation...
     (demodulatedRS,demodulatedNextRS,channelEstRefSymbols,sysParam);

% Extract out the header symbol samples and demod
refSamples = cfoCorrectedData( ...
    ((headerIdx-length(ssIdx))*numSampPerSym + (1:numSampPerSym)));
demodulatedHeader = ...
    ofdmdemod(refSamples,FFTLength,CPLength,symbOffset,nullIdx);
if sysParam.enableChest
    % eqHeaderData = ofdmEqualize(demodulatedHeader,estChannel(:,headerIdx-1));
    eqHeaderData = ofdmEqualize(demodulatedHeader,estChannel(:,1));
else
    eqHeaderData = demodulatedHeader;
end




headerInd = (usedSubCarr/2)-36+(1:72);
headerData = eqHeaderData(headerInd);

% Extract out and demodulate the data and pilot subcarriers
[demodulatedData,pilots] = ...
    ofdmdemod(dataHeaderFrame,FFTLength,CPLength,symbOffset,nullIdx,sysParam.pilotIdx);

% Perform channel equalization over entire data frame
if sysParam.enableChest
    estDataChanFrame = reshape(estChannel(dataIdx,2:end), ...
        [length(dataIdx)*(numSymPerFrame-length(ssIdx)-length(rsIdx)-length(headerIdx)) 1]);
    equalizedData = ofdmEqualize(...
        demodulatedData(:,headerIdx:end),estDataChanFrame);

% Equalize the pilots as well
    equalizedPilots = ofdmEqualize(pilots(:,headerIdx:end), ...
    reshape(estChannel((1:pilotSpacing:usedSubCarr),2:end),[],1));
else
    equalizedData = demodulatedData(:,headerIdx:end);
    equalizedPilots = pilots(:,headerIdx:end);
end




% Extract header and data subcarriers
userData = equalizedData;

% Recover header information and display decoded modulation, code rate
% and FFT Length
[headerBits,headerCRCErrFlag] = ...
    OFDMHeaderRecovery(headerData,sysParam);
[modOrder, codeIndex, ~, fftLength,...
    modName,codeRate] = OFDMHeaderUnpack(headerBits);
if isfield(sysParam,'isSDR')
    if modOrder ~= sysParam.modOrder
        warning('The modulation scheme detected (%s), does not match the modulation scheme mentioned in the data parameters (%dQAM). This results in invalid buffer sizes at the receiver and data decoding is not possible',modName, sysParam.modOrder);
    end
    if str2num(codeRate) ~= sysParam.codeRate
        warning('The codeRate detected (%s), does not match the codeRate mentioned in the data parameters (%d). This results in invalid buffer sizes at the receiver and data decoding is not possible',codeRate, sysParam.codeRate);
    end
end
if headerCRCErrFlag && sysParam.enableHeaderCRCcheck
    if verbosity > 0
        fprintf('Header CRC failed\n');
    end
    dataCRCErrFlag = 1;
    decodedDataBits = zeros(sysParam.trBlkSize,1);
else
    if verbosity > 0
        fprintf('Header CRC passed\n');
        fprintf('Modulation: %s, codeRate=%s, and FFT Length=%d\n',...
            modName, codeRate, fftLength);
    end
    sysParam.codeRate = str2num(codeRate);
    sysParam.modOrder = modOrder;
    sysParam.FFTLen = fftLength;
    % Perform common phase error (CPE) estimation on pilots and
    % compensate
    if sysParam.enableCPE
        % Calculate CPE estimate via averaged least-squares estimates from
        % the pilots
        cpeEst = sum(equalizedPilots.*pilotSignal)/length(pilotSignal);

        % Perform CPE correction
        % Normalize estimate to obtain just the phase error. The correction
        % is then applied to all the data subcarriers
        numSyms = size(userData,2);
        dataConstData = zeros(size(userData));
        
        for symIdx = 1:numSyms
            CPECorrection = (1/sqrt(abs(cpeEst(symIdx))))*conj(cpeEst(symIdx));
            dataEqualized = (userData(:,symIdx)) * CPECorrection;
            dataConstData(:,symIdx) = dataEqualized;
        end
    else
        dataConstData = userData;
    end

    % Recover data bits from data subcarriers
    % [llrOutput,decodedDataBits,dataCRCErrFlag] =...
    %     OFDMDataRecovery(squeeze(dataConstData),...
    %     4,0,sysParam);
    [llrOutput,decodedDataBits,dataCRCErrFlag] =...
        OFDMDataRecovery(squeeze(dataConstData),...
        modOrder,codeIndex,sysParam);
    softLLRs = llrOutput(:);
    if verbosity > 0
        if dataCRCErrFlag
            fprintf('Data CRC failed\n');
        else
            fprintf('Data CRC passed\n');
            fprintf('Data decoding completed\n');
            fprintf('------------------------------------------\n')
        end
    end
end

rxDataBits = double(decodedDataBits); % convert from logical type to double

% Assign output parameters
diagnostics = struct( ...
    'estCFO',freqOffset,...
    'estChannel',estChannel,...
    'rxConstellationHeader',headerData,...
    'rxConstellationData',dataConstData,...
    'softLLR',softLLRs,...
    'decodedCodeRateIndex',codeIndex,...
    'decodedModOrder',modOrder,...
    'headerCRCErrorFlag',headerCRCErrFlag,...
    'dataCRCErrorFlag',dataCRCErrFlag);

end

function [modOrder,codeRateIndex,fftLenIndex,fftLength,modType,codeRate] = OFDMHeaderUnpack(inBits)
%OFDMHeaderUnpack Unpacks bit information from header
% [modOrder, codeRateIndex, fftLenIndex,fftLength, modType, codeRate] = 
% OFDMHeaderUnpack(inBits)
% inBits - input header bits
% modOrder - modulation order
% codeRateIndex - code rate index
% fftLenIndex - FFT length index
% fftLength - FFT length
% modType - modulation type
% codeRate - code rate
% unpacks input header bits (inBits) into modulation order (modOrder),
% code rate index (codeRateIndex),FFT length index (fftLenIndex),
% FFT length (fftLength), modulation type (modType) and code rate
% (codeRate).

% First 3 bits of header represent FFT Length index
fftLenIndex = bit2int(inBits(1:3),3);

% Next 3 bits represent modulation index value
modIndex = bit2int(inBits(4:6),3);

% Next 2 bits represent code rate index
codeRateIndex = bit2int(inBits(7:8),2);

% Modulation order
if modIndex == 6
    modOrder = 4096;
elseif modIndex == 5
    modOrder = 1024;
elseif modIndex == 4
    modOrder = 256;
elseif modIndex == 3
    modOrder = 64;
elseif modIndex == 2
    modOrder = 16;
elseif modIndex == 1
    modOrder = 4;
else
    modOrder = 2;
end

% FFT Length value
switch fftLenIndex
    case 0
        fftLength = 64;
    case 2
        fftLength = 256;
    case 3
        fftLength = 512;
    case 4
        fftLength = 1024;
    case 5
        fftLength = 2048;
    case 6
        fftLength = 4096;
    otherwise
        fftLength = 128; % make default 128-length FFT
end

% Modulation Type
switch modOrder
    case 4
        modType = 'QPSK';
    case 16
        modType = '16QAM';
    case 64
        modType = '64QAM';
    case 256
        modType = '256QAM';
    case 1024
        modType = '1024QAM';
    case 4096
        modType = '4096QAM';
    otherwise
        modType = 'BPSK'; % make default BPSK
end

% Punctured code rate
switch codeRateIndex
    case 1
        codeRate = '2/3';
    case 2
        codeRate = '3/4';	
    case 3
        codeRate = '5/6';	
    otherwise
        codeRate = '1/2'; % make default index 0
end

end

function [headerBits,errFlag] = OFDMHeaderRecovery(headSymb,sysParam)
%OFDMHeaderRecovery Demodulates and decodes header information
% [headerBits,errFlag] = OFDMHeaderRecovery(headSymb,sysParam)
% takes header data symbols as input and outputs decoded and demodulated
% header information. This function also outputs the CRC Error flag.
% headSymb        - Demodulated constellation header symbols.
% sysParam        - system parameters structure
% headerBits      - Decoded header bits.
% errFlag         - CRC error flag, true if CRC failed

persistent crcDet;
if isempty(crcDet)
    crcDet = crcConfig(...
        'Polynomial',sysParam.headerCRCPoly, ...
        'InitialConditions',0, ...
        'FinalXOR',0);
end

traceBackDepth = 30;
deintrlvLen    = sysParam.headerIntrlvNColumns;

% Demodulate header symbol
softBits = pskdemod(headSymb(:), 2, ...
    OutputType="approxllr");

% Deinterleave
deintrlvOut = reshape(reshape(softBits,[],deintrlvLen).',[],1);

% Viterbi decoding
vitOut = vitdec((deintrlvOut(:)),...
    poly2trellis(sysParam.headerConvK,sysParam.headerConvCode), ...
    traceBackDepth,'term','unquant');

% CRC check
[headerBits,errFlag] = crcDetect(vitOut(1:(end-(sysParam.headerConvK-1))),crcDet);

end

function [softLLRs,outBits,errFlag] = OFDMDataRecovery(dataIn,modOrd,codeIn,sysParam)
%OFDMDataRecovery Recovers data bits
% [softLLRs,outBits,errFlag] = OFDMDataRecovery(dataIn,modOrd,codeIn,sysParam)
% performs symbol demodulation, deinterleaving, decoding, depuncturing,
% descrambling and checks CRC status. This function gives demodulated soft
% LLR information, decoded bits and CRC error flag as outputs.
% dataIn   - input data subcarriers
% modOrd   - modulation order
% codeIn   - code rate index
% sysParam - system parameters structure
% softLLRs - Soft LLR output of OFDM symbol demodulator
% outBits  - decoded bit output of Viterbi decoder
% errFlag  - CRC err flag, outputs 1 for CRC fail and 0 CRC pass.

% Create a persistent PN sequence object for use as an additive scrambler
persistent pnSeq;
if isempty(pnSeq)
    pnSeq = comm.PNSequence(Polynomial='x^-7 + x^-3 + 1',...
        InitialConditionsSource="Input port",...
        MaskSource="Input port",...
        VariableSizeOutput=true,...
        MaximumOutputSize=[sysParam.trBlkSize + sysParam.CRCLen + ...
            sysParam.dataConvK 1]);
end

% Create a persistent CRC object
persistent crcDet;
if isempty(crcDet)
    crcDet = crcConfig(...
        'Polynomial',sysParam.CRCPoly,...
        'InitialConditions',0,...
        'FinalXOR',0);
end

dataConvK      = sysParam.dataConvK;
dataConvCode   = sysParam.dataConvCode; 
traceBackDepth = sysParam.tracebackDepth; 
codeParam      = helperOFDMGetTables(codeIn);
puncVec        = codeParam.puncVec;

NData = size(dataIn,2);
len   = size(dataIn,1);
modIndex = log2(modOrd);
softLLRs = zeros(len*modIndex,NData);
deintrlvOut = zeros(size(softLLRs));
% dataIn = dataIn*4./norm(dataIn);
% Demodulate and deinterleave
for ii = 1:NData
    % Demodulate
    softLLRs(:,ii) = qamdemod(dataIn(:,ii),modOrd,...
        OutputType="approxllr", UnitAveragePower=true);

    % Deinterleave
    deintrlvOut(:,ii) = OFDMDeinterleave(softLLRs(:,ii), ...
        sysParam.dataIntrlvNColumns);
    % deintrlvOut(:,ii) = softLLRs(:,ii);
end

% Convolutional decoding
vitDecIn = deintrlvOut(:);
vitOut = vitdec((vitDecIn(1:end-sysParam.trBlkPadSize)), ...
    poly2trellis(dataConvK,dataConvCode), ...
    traceBackDepth,'term','unquant',puncVec);
vitOut2 = vitOut(1:end-(dataConvK-1));

% Descrambling
dataScrOut = xor(vitOut2, ...
                pnSeq(sysParam.initState,sysParam.scrMask,numel(vitOut2)));

% Output CRC
[outBits,errFlag] = crcDetect(dataScrOut,crcDet);

end

function deintrlvOut = OFDMDeinterleave(softLLRs,deintrlvLen)

lenIn = size(softLLRs,1);
numIntCols = ceil(lenIn/deintrlvLen);
numInPad = (deintrlvLen*numIntCols) - lenIn; % number of padded entries needed to make the input data length factorable
numFullRows = deintrlvLen - numInPad;
temp1 = reshape(softLLRs(1:numFullRows*numIntCols), ...
    numIntCols,numFullRows).'; % form full rows
if numInPad ~= 0
    temp2 = reshape(softLLRs(numFullRows*numIntCols+1:end), ...
        numIntCols-1,[]).'; % form partially-filled rows
    temp2 = [temp2 zeros(numInPad,1)];
else
    temp2 = [];
end
temp = [temp1; temp2]; % concatenate the two matrices
tempout = temp(:);
deintrlvOut = tempout(1:end-numInPad);

end
