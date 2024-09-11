function [OFDMParams, dataParams, all_BSsRadioResource] = getTrParamsforSpecificBS_id(overAllOfdmParams, index)
    % getTransmissionParams: Generate OFDM and Data parameters for a specific BS_id.
    % This function also saves transmission information for all BSs using
    % all_radioResource structure, which is passed as an input.
    %
    % Input:
    %   overAllOfdmParams - Global OFDM parameter structure
    %   BS_id - Base station ID for the current BS to calculate parameters
    %   BWPoffset - Offset in subcarriers for the BWP of the BS
    %   all_radioResource - Structure that stores all radio resource information for multiple BSs
    %
    % Output:
    %   OFDMParams - OFDM transmission parameters for the given BS
    %   dataParams - Data transmission parameters for the given BS
    %   all_radioResource - Updated structure that stores all radio resource information for multiple BSs
    checkParamsInput(overAllOfdmParams);

    % get current BS transmission parameters
    current_receiving_BS_id         = overAllOfdmParams.Rcv_DL_CoopBSs_id(index);
    current_receiving_BWPoffset     = overAllOfdmParams.BWPoffset(index);
    current_receiving_pilotscs      = overAllOfdmParams.PilotSubcarrierSpacing(index);
    % Define persistent variable to store all radio resources across multiple calls
    persistent all_radioResource;

    % 如果 all_radioResource 为空，则进行初始化
    if isempty(all_radioResource)
        all_radioResource.online_BS = overAllOfdmParams.online_BS;  % Store the number of online BS
        all_radioResource.num_BWPs = overAllOfdmParams.online_BS;   % Number of BWPs equals number of BS
        all_radioResource.BWPs = struct();                         % Structure to store BWP information for each BS
        all_radioResource.TrRcOFDMParams = struct();                   % Structure to store OFDMParams for each BS
        all_radioResource.TrRcdataParams = struct();                   % Structure to store dataParams for each BS
    end

    % 获取当前基站分配的无线资源, calculate allocated radio resource
    [alloc_RadioResource, ~] = calculateBWPs(overAllOfdmParams, current_receiving_BS_id, current_receiving_BWPoffset);

    % OFDM transmission parameters based on the BS_id and allocated resources
    OFDMParams.online_BSs             = overAllOfdmParams.online_BS;                 % Total number of online BS
    OFDMParams.CrtRcv_DL_CoopBS_id    = current_receiving_BS_id;                                       % Current BS id
    OFDMParams.FFTLength              = overAllOfdmParams.FFTLength;                 % FFT length
    OFDMParams.CPLength               = overAllOfdmParams.CPLength;                  % Cyclic prefix length
    OFDMParams.PilotSubcarrierSpacing = current_receiving_pilotscs;    % Pilot sub-carrier spacing
    
    % Resource block and subcarrier allocation for the current BS
    OFDMParams.NumSubcarriers         = alloc_RadioResource.UsedSubcc;               % Number of sub-carriers in the band
    OFDMParams.subcarrier_start_index = alloc_RadioResource.subcarrier_start_index;   % BWP start index
    OFDMParams.subcarrier_end_index   = alloc_RadioResource.subcarrier_end_index;     % BWP end index
    OFDMParams.subcarrier_center_offset = alloc_RadioResource.subcarrier_center_offset; % BWP center offset (relative to DC subcarrier)
    OFDMParams.BWPoffset              = alloc_RadioResource.BWPoffset;               % Manually set BWP offset
    OFDMParams.Subcarrierspacing      = overAllOfdmParams.Subcarrierspacing;                                        % Sub-carrier spacing (Hz)
    OFDMParams.guard_interval         = overAllOfdmParams.guard_interval;            % Guard interval for the allocated spectrum
    
    % Calculate the channel bandwidth based on the allocated subcarriers and guard interval
    OFDMParams.channelBW              = (OFDMParams.guard_interval + OFDMParams.NumSubcarriers) * OFDMParams.Subcarrierspacing;
    OFDMParams.signalBW               = (2 * OFDMParams.guard_interval + OFDMParams.NumSubcarriers) * OFDMParams.Subcarrierspacing;

    % Data transmission parameters - switch based on BS_id，目前最高支持到4个cooperative BS
    % Modulation order (64-QAM)
          % Options:
          %  2    -> BPSK
          %  4    -> QPSK
          %  16   -> 16-QAM
          %  64   -> 64-QAM
          %  256  -> 256-QAM
          %  1024 -> 1024-QAM
          %  4096 -> 4096-QAM

    % Code rate
          % Options:
          %  "1/2" -> 1/2 code rate
          %  "2/3" -> 2/3 code rate
          %  "3/4" -> 3/4 code rate
          %  "5/6" -> 5/6 code rate

    % dataParams.numSymPerFrame = 30;
          % Number of symbols per frame
          % This parameter should be configured
          % according to the specific base station settings

    % dataParams.numFrames  = 30;    
          % Number of frames to transmit
          % This parameter should be configured
          % according to the specific base station settings
    switch current_receiving_BS_id
        case 1
            % 配置基站1的DataParams
            dataParams.modOrder       = 256;    % Modulation order (64-QAM)
            dataParams.coderate       = "2/3"; % Code rate, option for "1/2""2/3""3/4""5/6"
            dataParams.numSymPerFrame = 30;    % Number of symbols per frame
            dataParams.numFrames      = 30;    % Number of frames to transmit
            dataParams.enableScopes   = true;  % Enable scopes for visualization
            dataParams.verbosity      = true;  % Enable verbosity for diagnostics
            dataParams.printData      = true;  % Print received data
            dataParams.enableConst_measure = true; % Enable constellation measurement

        case 2
            % 配置基站2的DataParams
            dataParams.modOrder       = 64;    % Modulation order (64-QAM)
            dataParams.coderate       = "5/6"; % Code rate
            dataParams.numSymPerFrame = 30;    % Number of symbols per frame
            dataParams.numFrames      = 30;    % Number of frames to transmit
            dataParams.enableScopes   = true;  % Enable scopes for visualization
            dataParams.verbosity      = true;  % Enable verbosity for diagnostics
            dataParams.printData      = true;  % Print received data
            dataParams.enableConst_measure = true; % Enable constellation measurement

        case 3
            % 配置基站3的DataParams
            dataParams.modOrder       = 64;    % Modulation order (64-QAM)
            dataParams.coderate       = "1/2"; % Code rate
            dataParams.numSymPerFrame = 30;    % Number of symbols per frame
            dataParams.numFrames      = 30;    % Number of frames to transmit
            dataParams.enableScopes   = true;  % Enable scopes for visualization
            dataParams.verbosity      = true;  % Enable verbosity for diagnostics
            dataParams.printData      = true;  % Print received data
            dataParams.enableConst_measure = true; % Enable constellation measurement

         case 4
            % 配置基站4的DataParams
            dataParams.modOrder       = 64;    % Modulation order (64-QAM)
            dataParams.coderate       = "1/2"; % Code rate
            dataParams.numSymPerFrame = 30;    % Number of symbols per frame
            dataParams.numFrames      = 30;    % Number of frames to transmit
            dataParams.enableScopes   = true;  % Enable scopes for visualization
            dataParams.verbosity      = true;  % Enable verbosity for diagnostics
            dataParams.printData      = true;  % Print received data
            dataParams.enableConst_measure = true; % Enable constellation measurement
            
        otherwise
            % 默认配置
            error('The given BS id is not supported(exceeds the total supported numbers 4!)');
            dataParams.modOrder       = 16;    % Modulation order (16-QAM)
            dataParams.coderate       = "1/2"; % Default code rate
            dataParams.numSymPerFrame = 30;    % Number of symbols per frame
            dataParams.numFrames      = 30;    % Number of frames to transmit
            dataParams.enableScopes   = true;  % Enable scopes for visualization
            dataParams.verbosity      = true;  % Enable verbosity for diagnostics
            dataParams.printData      = true;  % Print received data
            dataParams.enableConst_measure = true; % Enable constellation measurement
    end
    % 更新 all_radioResource 中的信息, 保存该基站的BWP、OFDMParams 和 dataParams
    names = "DL_BS_" + string(num2str(current_receiving_BS_id));
    all_radioResource.BWPs.(names)                      = alloc_RadioResource;
    all_radioResource.TrRcOFDMParams.(names)            = OFDMParams;
    all_radioResource.TrRcdataParams.(names)            = dataParams;
    all_BSsRadioResource = all_radioResource;
end


function checkParamsInput(overAllOfdmParams)
    % checkParamsConsistency: Function to check the consistency of the OFDM parameters
    % Input:
    %   overAllOfdmParams - Structure containing OFDM configuration parameters
    %
    % Checks:
    %   - Length of Rcv_DL_CoopBSs_id matches PilotSubcarrierSpacing and BWPoffset
    %   - No duplicate IDs in Rcv_DL_CoopBSs_id
    %   - All values in Rcv_DL_CoopBSs_id are positive integers

    % 检查Rcv_DL_CoopBSs_id是否超出最大允许取到的ID值(online_BS)
    if length(overAllOfdmParams.Rcv_DL_CoopBSs_id) > overAllOfdmParams.online_BS
        error(['Parameters illegal: The given number of cooperative BS (%d) exceeds total number' ...
            'of online BS (%d)'], ...
            length(overAllOfdmParams.Rcv_DL_CoopBSs_id), overAllOfdmParams.online_BS);
    end

    % 检查Rcv_DL_CoopBSs_id长度是否与PilotSubcarrierSpacing、BWPoffset一致
    if length(overAllOfdmParams.Rcv_DL_CoopBSs_id) ~= length(overAllOfdmParams.PilotSubcarrierSpacing)
        error(['Parameters mismatch: The total length of necessary setting parameter' ...
            ': PilotSubcarrierSpacing (%d) does not match the given number of cooperative BS (%d)'], ...
            length(overAllOfdmParams.PilotSubcarrierSpacing), length(overAllOfdmParams.Rcv_DL_CoopBSs_id));
    end
    
    if length(overAllOfdmParams.Rcv_DL_CoopBSs_id) ~= length(overAllOfdmParams.BWPoffset)
        error(['Parameters mismatch: The total length of necessary setting parameter' ...
            ': BWPoffset (%d) does not match the given number of cooperative BS (%d)'], ...
            length(overAllOfdmParams.BWPoffset), length(overAllOfdmParams.Rcv_DL_CoopBSs_id));
    end

    % 检查Rcv_DL_CoopBSs_id数组是否有重复值
    if numel(unique(overAllOfdmParams.Rcv_DL_CoopBSs_id)) ~= numel(overAllOfdmParams.Rcv_DL_CoopBSs_id)
        error('Parameters error: The array Rcv_DL_CoopBSs_id contains duplicate IDs, which is not allowed.');
    end

    % 检查Rcv_DL_CoopBSs_id数组是否全部为整数
    if any(overAllOfdmParams.Rcv_DL_CoopBSs_id ~= floor(overAllOfdmParams.Rcv_DL_CoopBSs_id))
        error('Parameters error: The array Rcv_DL_CoopBSs_id contains non-integer values. All values must be integers.');
    end

    % 检查Rcv_DL_CoopBSs_id数组的元素是否为正整数
    if any(overAllOfdmParams.Rcv_DL_CoopBSs_id <= 0)
        error('Parameters error: The array Rcv_DL_CoopBSs_id contains non-positive values. All values must be positive integers.');
    end
end

