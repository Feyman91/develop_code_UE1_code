function codeStruct = helperOFDMGetTables(codeRateIndex)
%helperOFDMGetTables Return common tx/rx parameters.
%   This helper is called from the tx and rx functions to return a common
%   set of system parameters from index pointer. Index a desired bandwidth
%   index to return the FFT length, CP length, subcarrier spacing (symbol
%   rate), and number of data subcarriers per OFDM symbol.
%
%   codeStruct = helperOFDMGetTables(BWIndex,codeRateIndex)
%   codeRateIndex - index into code rate table
%
%   codeStruct = structure comprising code rate, puncture vector,
%   constraint length, and traceback depth of the convolutional coder.

% Copyright 2024 The MathWorks, Inc.


% Select puncture vector and punctured code rate. The traceback depth of
% the Viterbi decoder roughly follows a rule of thumb of 2x-3x the factor
% (constraint length - 1) / (1 - codeRate)
codeStruct = struct( ...
     'puncVec',[], ...
     'codeRate',[], ...
     'codeRateK',[], ...
     'tracebackDepth',[]);
switch codeRateIndex
    case 1
        codeStruct.puncVec = [1 1 0 1];
        codeStruct.codeRate = 2/3;
        codeStruct.codeRateK = 3;
        codeStruct.tracebackDepth = 45;
    case 2
        codeStruct.puncVec = [1 1 1 0 0 1];
        codeStruct.codeRate = 3/4;
        codeStruct.codeRateK = 4;
        codeStruct.tracebackDepth = 60;
    case 3
        codeStruct.puncVec = [1 1 1 0 0 1 1 0 0 1];
        codeStruct.codeRate = 5/6;
        codeStruct.codeRateK = 6;
        codeStruct.tracebackDepth = 90;
    otherwise
        % Default to index 0
        codeStruct.puncVec = [1 1];
        codeStruct.codeRate = 1/2;
        codeStruct.codeRateK = 2;
        codeStruct.tracebackDepth = 30;
end

end


