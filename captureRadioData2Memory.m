% Clear all the function data as they contain some persistent variables
clear;
clear helperOFDMRx helperOFDMRxFrontEnd helperOFDMRxSearch helperOFDMFrequencyOffset getTrParamsforSpecificBS_id;
close all;
% 第一部分可以认为是控制基站的功能
% The chosen set of OFDM parameters overall for all BSs:
overAllOfdmParams.online_BS               = 1;              % number of online data BS 
overAllOfdmParams.FFTLength               = 256;              % FFT length
overAllOfdmParams.CPLength                = ceil(overAllOfdmParams.FFTLength*0.25);   % Cyclic prefix length
overAllOfdmParams.Subcarrierspacing       = 30e3;               % Sub-carrier spacing of 30 KHz
total_RB                                  = 17;                                % User input Resource block number

% 调用calculateRBFinal函数确保最终的RB确定的子载波总数能够被pilot subcarrier spacing整除
[RB_verified, MaxRB] = calculateRBFinal(overAllOfdmParams, total_RB);
% 补充，其实新的算法不需要这个强限制，直接传入total RB即可

% check if RB_verified exceed MaxRB
if total_RB > MaxRB || RB_verified > MaxRB
    error('Error: Defined RB (%d) exceeds the system maximum allowed RB (%d). ', RB_verified, MaxRB);
end

overAllOfdmParams.total_RB                     = total_RB;
overAllOfdmParams.total_NumSubcarriers         = overAllOfdmParams.total_RB*12;                  % Number of sub-carriers in the band = resourceblock * 12 (must less than FFTlength)
overAllOfdmParams.guard_interval = (overAllOfdmParams.FFTLength - overAllOfdmParams.total_NumSubcarriers) / 2;     % Guard interval, 单侧的空载波
% check if NumSubcarriers less than FFTLength
if overAllOfdmParams.total_NumSubcarriers > overAllOfdmParams.FFTLength
    error('Total NumSubcarriers: (%d) exceeds Total FFTLength: (%d), which is not allowed. Please reduce the value of RB.', ...
        overAllOfdmParams.total_NumSubcarriers, overAllOfdmParams.FFTLength);
end
radioDevice            = "B210";   % Choose radio device for reception
channelmapping         = 1;  % mutichannel or single channel selection
centerFrequency        = 2.2e9;
gain                   = 55; % Set radio gain
read_savedData         = false;

% cfg 用来配置是否进行burst传输、CFO、CPE、信道均衡操作，显示示波器，可视化计算结果等。
cfg.enableBurstMode      = false;               % 是否选择进行突发接收（适当的采用burst传输以避免overflow，true表示启用burst传输，不是实时的，False表示禁用burst传输，是实时的）
cfg.burstbuffersize      = 30;                  %（只有当enableBurstMode为Ture才有效）设定突发传输的buffer大小（一个buffer的总帧数）
cfg.enableCFO            = true;
cfg.enableCPE            = false;
cfg.enableChest          = true;
cfg.enableHeaderCRCcheck = true;
cfg.enableTimescope      = false;
cfg.enableScopes         = true;
cfg.verbosity            = true;
cfg.printData            = true;
cfg.enableConst_measure  = true;
read_filename = 'saved_frameData.bb';            % read saved received data from specific filename         
save_filename = 'received_buffer.bb';           % save receiving data to specific filename

% 接下来是针对UE B210联合分别接收不同基站数据的radio设置和具体接收算法流程+resource OFDM parameters
overAllOfdmParams.Rcv_DL_CoopBSs_id                   = [1];                %当前服务该用户的下行基站协作集, 接收BS id信号处理的顺序与list前后顺序一致
overAllOfdmParams.PilotSubcarrierSpacing              = [36];              % Pilot sub-carrier spacing
overAllOfdmParams.BWPoffset                           = [0];                %当前基站的总带宽offset（单位/1个子载波），offset设置的是实际带宽start位置相对于初始计算的start的位置的偏移
UE_id                                                 = 1;                    %当前UE的ID标识符
% 根据全局configure和特定配置，初始化所有接收下行基站的 sysParam、rxObj、OFDMParams、dataParams等参数保存至sysParamRxObj
sysParamRxObj = setupSysParamsAndRxObjects(overAllOfdmParams, cfg);
% 检查 sysParamRxObj 中所有基站的 field names和预先确定的overAllOfdmParams中协作基站集ID名称和顺序是否一致
BS_fieldnames = fieldnames(sysParamRxObj);
% 初始化接收机USRP radio和软接收object basbandreceiver bbr
radio = GetRxUsrpRadioObj(sysParamRxObj,radioDevice,centerFrequency,gain,channelmapping,read_savedData,read_filename);

%% 创建基带文件写入对象
root = "E:\FDRAN_Prototype\cache_file\";
filename = root + "received_buffer.bin";

% 定义 numElements
totalMemorySizeInGB = 4;  % 4GB
totalMemorySizeInBytes = totalMemorySizeInGB * (1024^3);  % 4GB in bytes
numElements = totalMemorySizeInBytes/(8*2);
% numElements = 2^28;  % 定义为全局变量，2^28 doubles 约等于 2GB,为存储实部/虚部的大小
% expectedSize = numElements * 2 * 8;  % 期望的文件大小 (字节): 4GB，为总的buffer size

% 创建一个共享的 zero 变量，以供后续写入和内存映射初始化使用
zeroData = zeros(numElements, 2, 'double');  % 初始化 2 列：第1列实部，第2列虚部

% 检查文件是否已经存在，如果不存在则创建
if ~exist(filename, 'file')
    [f, msg] = fopen(filename, 'w');
    if f ~= -1
        % 预分配2GB用于实部和2GB用于虚部的缓存 (double类型: 每个元素8字节)
        % 分配空间共4GB, 对应2^30字节大小。
        fwrite(f, zeroData, 'double');  % 实部和虚部分别写入
        fclose(f);
        disp('File preallocated successfully.');
    else
        error('File creation failed: %s', msg);
    end
else
    % 如果文件已经存在，检查它的大小是否符合预期
    fileInfo = dir(filename);

    if fileInfo.bytes ~= totalMemorySizeInBytes
        error('File size mismatch: expected %d bytes, but found %d bytes.', totalMemorySizeInBytes, fileInfo.bytes);
    else
        fprintf('File already exists and matches expected size %d GB.\n', totalMemorySizeInGB);
        
        % 提示用户决定是否继续
        fprintf('The file already contains data. Please check if you want to proceed.\n');
        fprintf('Press Enter to continue...');
        
        % 等待用户输入回车继续执行
        input('');
    end
end
disp('Starting Memory mapping...');
%% 使用 memmapfile 进行内存映射
m = memmapfile(filename, ...
    'Format', {'double', [numElements 2], 'complexData'}, ...  % 2列：第1列实部，第2列虚部
    'Writable', true);

disp('Memory mapping established.');

% **预初始化内存映射区域**，避免首次写入时延迟
% 直接使用 zeroData 写入到内存映射区域,
m.Data.complexData = zeroData;
disp('Memory mapping initialized with zero data.');

%% 初始化接收参数
framesize = sysParamRxObj.DL_BS_1.sysParam.txWaveformSize;
samplerate = sysParamRxObj.DL_BS_1.sysParam.SampleRate;
timePerFrame = framesize / samplerate; 

enable_time_limit_transmission = true; % 是否根据给定时间传输。若为false，则指定帧数传输
if enable_time_limit_transmission
    %指定总时间传输
    rcvtime = 10;       % units: seconds
    numFrame = floor(rcvtime/timePerFrame);
else
    %指定帧数传输
    numFrame = 10000;       
end
overflow = 0;
% 计算总接收时间 (秒)
totalTime = numFrame * timePerFrame;
[maxRcvFrames, maxRcvTime] = calculateTotalFramesAndTime(totalMemorySizeInGB, framesize, samplerate);
fprintf('buffer能接收的最大总帧数：%d \n /当前接收总帧数: %d\n', maxRcvFrames, numFrame);
fprintf('buffer能接收的最大总接收时间：%.2f 秒 \n / 当前总接收时间: %.2f 秒\n', maxRcvTime, totalTime);
if numFrame > maxRcvFrames
    error('set received total frame length (%d) exceeds max length of buffer (%d) for receiving!',numFrame,maxRcvFrames)
end
if totalTime > maxRcvTime
    error('set received total time (%.3f) exceeds max time length of buffer (%.3f) for receiving!',totalTime,maxRcvTime)
end
%% 开始接收数据，直到达到总持续时间

fprintf('Press Enter to start USRP capturing...');
input('');
% 初始化索引列表
startIdxList = zeros(numFrame, 1);  % 存储每帧的 startIdx
endIdxList = zeros(numFrame, 1);    % 存储每帧的 endIdx
% 在循环外预先计算所有帧的 startIdx 和 endIdx
for frameNum = 1:numFrame
    startIdxList(frameNum) = (frameNum - 1) * framesize + 1;
    endIdxList(frameNum) = frameNum * framesize;
end
start_time = tic();
% data_collec = zeros(numFrame*framesize,1);
for frameNum = 1:numFrame
    % 接收来自USRP的基带信号
    % 接收来自 USRP 的基带复数信号 (complex double)
    [rxWaveform, ~, overflow] = radio();  % 从 USRP 设备接收数据
    
    if overflow > 0
        fprintf('Overflow detected in frame %d. Skipping frame.\n', frameNum);
        continue;  % 如果发生 overflow，跳过这一帧
    else
        % 确定当前帧在内存映射文件中的索引(使用预先计算的索引)
        % 一次性将实部和虚部数据写入内存映射文件中指定位置
        m.Data.complexData(startIdxList(frameNum):endIdxList(frameNum), :) = [real(rxWaveform), imag(rxWaveform)];
        % data_collec(startIdxList(frameNum):endIdxList(frameNum)) = rxWaveform;
    end
end
end_time = toc(start_time);

disp('Data reception complete.');
fprintf('Total Receiving Time: %.2f s\n', end_time)
% bbw = comm.BasebandFileWriter(save_filename, SampleRate=samplerate, CenterFrequency=centerFrequency);
% bbw(data_collec);
% info(bbw)
% release(bbw);


% 释放资源
% 关闭文件
release(radio);

%% 
function [totalFrames, totalTime] = calculateTotalFramesAndTime(totalMemorySizeInGB, framesize, samplerate)
    % 计算内存大小 (单位：字节)
    totalMemorySizeInBytes = totalMemorySizeInGB * (1024^3);
    
    % 每帧包含的字节数：每帧有 framesize 个复数采样点，每个复数采样点有两个 double（实部和虚部），每个 double 占用 8 字节
    bytesPerFrame = framesize * 2 * 8;
    
    % 计算总帧数
    totalFrames = floor(totalMemorySizeInBytes / bytesPerFrame);
    
    % 每帧的持续时间 (秒)
    timePerFrame = framesize / samplerate;
    
    % 计算总接收时间 (秒)
    totalTime = totalFrames * timePerFrame;
end
