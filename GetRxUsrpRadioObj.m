function radio = GetRxUsrpRadioObj(sysParamRxObj,radioDevice,centerFrequency,gain,channelmapping,read_savedData,read_filename)
%helperGetRadioTxObj(OFDMTX) returns the radio system object RADIO, based
%   on the chosen radio device and radio parameters such as Gain,
%   CentreFrequency, MasterClockRate, and Interpolation factor from the
%   radioParameter structure OFDMTX. The function additionally gives the
%   constellation diagram and spectrumAnalyzer system objects as output for
%   data visualizations
field_name = fieldnames(sysParamRxObj);
sysParam = getfield(sysParamRxObj,field_name{1}).sysParam;
ofdmRx = helperGetRadioParams(sysParam,radioDevice,sysParam.SampleRate,centerFrequency,gain,channelmapping);
radio = helperGetRadioRxObj(ofdmRx);
if read_savedData
    radio = comm.BasebandFileReader(read_filename, SamplesPerFrame=sysParam.txWaveformSize);
end
end