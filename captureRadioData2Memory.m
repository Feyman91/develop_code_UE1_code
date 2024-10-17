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

%% 创建基带文件写入对象，初始化接收参数
root = "E:\FDRAN_Prototype\cache_file\";
filename = root + "received_buffer_new.bin";
framesize = sysParamRxObj.DL_BS_1.sysParam.txWaveformSize;
samplerate = sysParamRxObj.DL_BS_1.sysParam.SampleRate;

%% Define the data structure for the memory-mapped file
% 定义缓存空间大小
totalMemorySizeInGB = 4;  % 4GB
totalMemorySizeInBytes = totalMemorySizeInGB * (1024^3);  % 4GB in bytes

% 定义结构化message，通过报头报文管理内存空间数据字段。
% Each message will have a header flag (int32) and data (double array)
headerSize = 4;  % bytes for int32
dataSizePerMessage = framesize * 16;  % framesize samples * 16 bytes per complex double sample
bytesPerMessage = headerSize + dataSizePerMessage;
totalMessages = floor(totalMemorySizeInBytes / bytesPerMessage);

% 定义内存映射文件的数据结构
% 我们将内存映射文件划分为两个部分：
% 1. headerFlags: int32 类型的数组，大小为 [totalMessages x 1]
% 2. complexData: double 类型的数组，大小为 [totalMessages * framesize , 2]

% 计算各部分的大小
headerSize = 4 * totalMessages;  % 每个 int32 4 字节
dataSize = totalMessages * framesize * 2 * 8;  % 每个复数分实部虚部各采样点 8 字节 (double 实部和虚部)

% 总文件大小
totalFileSize = headerSize + dataSize;

% 创建用于初始化的零数组
zeroHeader = zeros(totalMessages, 1, 'int32');
zeroData = zeros(totalMessages * framesize, 2, 'double');

% 检查文件是否已经存在，如果不存在则创建
% Create the memory-mapped file with the new structure
if ~exist(filename, 'file')
    [f, msg] = fopen(filename, 'w');
    
    if f ~= -1
        % Set the file size to the total size needed
        % 先写入 headerFlags 的零值
        countHeader = fwrite(f, zeroHeader, 'int32');
        if countHeader ~= totalMessages
            error('写入 headerFlags 时发生错误。预期写入 %d 个元素，但实际写入 %d 个。', totalMessages, countHeader);
        end
        % 然后写入 data 的零值
        countData = fwrite(f, zeroData, 'double');
        if countData ~= totalMessages * framesize * 2
            error('写入 data 时发生错误。预期写入 %d 个元素，但实际写入 %d 个。', totalMessages * framesize * 2, countData);
        end
        fclose(f);
        disp('File preallocated successfully.');
    else
        error('File creation failed: %s', msg);
    end
else
    % If the file exists, check its size
    fileInfo = dir(filename);
    expectedFileSize = totalFileSize;
    if fileInfo.bytes ~= expectedFileSize
        error('File size mismatch: expected %d bytes, but found %d bytes.', expectedFileSize, fileInfo.bytes);
    else
        fprintf('File already exists and matches expected size %d bytes.\n', expectedFileSize);
        
        % 提示用户决定是否继续
        fprintf('The file already contains data. Please check if you want to proceed.\n');
        fprintf('Press Enter to continue...');
        
        % 等待用户输入回车继续执行
        input('');
    end
end
disp('Starting Memory mapping...');

%% 使用 memmapfile 进行内存映射
% Map the file with the new structure
m = memmapfile(filename, ...
    'Format', { ...
        'int32', [totalMessages, 1], 'headerFlags'; ...
        'double', [totalMessages * framesize, 2], 'complexData' ...
    }, ...
    'Writable', true);

disp('Memory mapping established.');

% **预初始化内存映射区域**，避免首次写入时延迟
% 直接使用 zeroData 写入到内存映射区域,
% 注意初始化 headerFlags 为 1（表示数据已被处理）
m.Data.headerFlags(:) = 1;
m.Data.complexData = zeroData;
disp('Memory mapping initialized with zero data.');

%% 确定接收模式，是否进行持续性接收，还是指定帧数和时间的接收
timePerFrame = framesize / samplerate; 
% 确定当前buffer能缓存的最大总帧数和接收时间。实际上maxRcvFrames等价于totalMessages
[maxRcvFrames, maxRcvTime] = calculateTotalFramesAndTime(totalMessages, framesize, samplerate);
% 添加选择接收模式的变量
continuousReception = true;  % true 表示持续接收，false 表示接收指定长度

if continuousReception
    % 持续接收模式，不指定 numFrame 或 rcvtime
    maxFrames = totalMessages;  % 缓冲区能容纳的最大帧数
    disp('***************Enable continous reception!***************')
    fprintf('buffer能储存的最大总帧数：%d \n', maxRcvFrames);
    fprintf('buffer能储存的最大总接收时间：%.2f 秒 \n', maxRcvTime);
else
    % 指定接收时间或帧数
    disp('***************Enable desired limit length reception!***************')
    enable_time_limit_transmission = true; % 是否根据给定时间传输。若为false，则指定帧数传输
    if enable_time_limit_transmission
        % 指定总时间传输
        rcvtime = 10;       % 单位：秒
        numFrame = floor(rcvtime / timePerFrame);
    else
        % 指定帧数传输
        numFrame = 10000;       
    end

    totalTime = numFrame * timePerFrame;
    fprintf('buffer能接收的最大总帧数：%d \n /当前指定接收总帧数: %d\n', maxRcvFrames, numFrame);
    fprintf('buffer能接收的最大总接收时间：%.2f 秒 \n / 当前指定总接收时间: %.2f 秒\n', maxRcvTime, totalTime);
    if numFrame > maxRcvFrames
        error('set received total frame length (%d) exceeds max length of buffer (%d) for receiving!',numFrame,maxRcvFrames)
    end
    if totalTime > maxRcvTime
        error('set received total time (%.3f) exceeds max time length of buffer (%.3f) for receiving!',totalTime,maxRcvTime)
    end
    maxFrames = numFrame;
end

%% 初始化中断当前接收状态的共享文件（存储 中断flag 用）
flagFile = 'interrupt_reception_flag.bin';

% 如果文件不存在，初始化并写入默认 flag 值
if ~isfile(flagFile)
    fid = fopen(flagFile, 'w');
    fwrite(fid, 1, 'int32');  % 初始化 flag 为 1，表示继续运行
    fclose(fid);
end

% 创建内存映射文件对象
m_ctlflag = memmapfile(flagFile, 'Writable', true, 'Format', 'int32');

% flag置为1表示开始持续性接收
m_ctlflag.Data(1) = 1;
%% 开始接收数据并保存到主机buffer中，直到达到总持续时间 or 一直接收所有数据，直到中断接收flag被触发
fprintf('Press Enter to start USRP capturing...');
input('');

% 预计算索引列表（对于最大可能的帧数）
startIdxList = zeros(totalMessages, 1);  % 存储每帧的 dataStartIdx
endIdxList = zeros(totalMessages, 1);    % 存储每帧的 dataEndIdx
for i = 1:totalMessages
    startIdxList(i) = (i - 1) * framesize + 1;
    endIdxList(i) = i * framesize;
end

% 初始化帧数指针, 接收USRP数据
writeFramePointer = 1;
start_time = tic();
if continuousReception
    % 持续接收模式
    while m_ctlflag.Data
        % 从 USRP 接收数据
        [rxWaveform, ~, overflow] = radio();

        if overflow > 0
            fprintf('Overflow detected in frame %d. Skipping frame.\n', writeFramePointer);
            continue;  % 如果发生溢出，跳过这一帧
        else
            % 检查 headerFlag, 如果为0，表示未被处理，抛出覆盖警告
            if ~m.Data.headerFlags(writeFramePointer)
                error('The data at frame %d has not yet been processed. Overwriting unprocessed data', writeFramePointer);
            end

            % 确定当前帧在内存映射文件中的索引(使用预先计算的索引)
            % 一次性将实部和虚部数据写入内存映射文件中指定位置
            m.Data.complexData(startIdxList(writeFramePointer):endIdxList(writeFramePointer), :) = [real(rxWaveform), imag(rxWaveform)];
           
            % 将 headerFlag 设置为 0（表示数据尚未处理）
            m.Data.headerFlags(writeFramePointer) = 0;
            
            % 增加写指针，循环缓冲区
            writeFramePointer = writeFramePointer + 1;
            if writeFramePointer > totalMessages
                writeFramePointer = 1;
            end
        end
    end
    disp('检测到中断信号，停止接收。');

else
    % 指定长度接收模式
    for frameNum = 1:maxFrames
        % 从 USRP 接收数据
        [rxWaveform, ~, overflow] = radio();
        
        if overflow > 0
            fprintf('Overflow detected in frame %d. Skipping frame.\n', frameNum);
            continue;  % 如果发生 overflow，跳过这一帧
        else    
            % 检查 headerFlag
            if ~m.Data.headerFlags(writeFramePointer)
                warning('The data at frame %d has not yet been processed. Overwriting unprocessed data', writeFramePointer);
            end
            
            % 确定当前帧在内存映射文件中的索引(使用预先计算的索引)
            % 一次性将实部和虚部数据写入内存映射文件中指定位置
            m.Data.complexData(startIdxList(writeFramePointer):endIdxList(writeFramePointer), :) = [real(rxWaveform), imag(rxWaveform)];
           
            % 将 headerFlag 设置为 0（表示数据尚未处理）
            m.Data.headerFlags(writeFramePointer) = 0;
            
            % 增加写指针，循环缓冲区
            writeFramePointer = writeFramePointer + 1;
        end
    end
end
end_time = toc(start_time);

disp('Data reception complete.');
fprintf('Total Number of Receiving Frames: %d \n', writeFramePointer)
fprintf('Total Receiving Time: %.2f s\n', end_time)

% 释放资源
release(radio);

%% 调整后的函数，用于计算总帧数和时间
function [totalFrames, totalTime] = calculateTotalFramesAndTime(totalMessages, framesize, samplerate)
    totalFrames = totalMessages;
    timePerFrame = framesize / samplerate;
    totalTime = totalFrames * timePerFrame;
end
