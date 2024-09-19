function [sysParamRxObj] = setupSysParamsAndRxObjects(overAllOfdmParams, cfg)
    % setupSysParamsAndRxObjects: Set up system parameters, receiver objects, 
    % OFDM transmission parameters, and other related parameters for all BSs.
    %
    % Input:
    %   overAllOfdmParams - Global OFDM parameter structure
    %
    % Output:
    %   sysParamRxObj - Structure containing system parameters, receiver objects,
    %                   OFDMParams, dataParams, all_radioResource, and txParam for each BS

    % 初始化保存所有基站 sysParam 和相关参数的结构体
    sysParamRxObj = struct();

    % 遍历所有在线基站，分别为每个基站初始化 sysParam、rxObj、OFDMParams、dataParams 等
    for index = 1:length(overAllOfdmParams.Rcv_DL_CoopBSs_id)
        % 获取当前基站的 ID
        current_BS_id = overAllOfdmParams.Rcv_DL_CoopBSs_id(index);

        % 获取基站的传输参数
        [OFDMParams, dataParams, all_radioResource] = getTrParamsforSpecificBS_id(overAllOfdmParams, index, cfg);
        [sysParam, txParam, transportBlk_bs] = helperOFDMSetParamsSDR(OFDMParams, dataParams, all_radioResource);

        % 计算总子载波数和采样率
        sysParam.total_usedSubcc = overAllOfdmParams.total_NumSubcarriers;
        sysParam.total_usedRB = overAllOfdmParams.total_RB;
        sysParam.SampleRate = sysParam.scs * sysParam.FFTLen;

        %%%%%%%%%%%%%%%%%%%%%%%%% 设置可选参数 %%%%%%%%%%%%%%%%%%%%%%%%%
        sysParam.enableTimescope        = cfg.enableTimescope;
        sysParam.enableCFO              = cfg.enableCFO;
        sysParam.enableCPE              = cfg.enableCPE;
        sysParam.enableChest            = cfg.enableChest;
        sysParam.enableHeaderCRCcheck   = cfg.enableHeaderCRCcheck;
        %%%%%%%%%%%%%%%%%%%%%%%%% 设置可选参数 %%%%%%%%%%%%%%%%%%%%%%%%%

        % 初始化接收对象 rxObj
        rxObj = helperOFDMRxInit(sysParam);

        % 将 sysParam、rxObj、OFDMParams、dataParams、all_radioResource、txParam 和误码率对象保存到结构体中
        sysParamRxObj.(sprintf('DL_BS_%d', current_BS_id)).sysParam = sysParam;
        sysParamRxObj.(sprintf('DL_BS_%d', current_BS_id)).rxObj = rxObj;
        sysParamRxObj.(sprintf('DL_BS_%d', current_BS_id)).transportBlk_bs = transportBlk_bs;
        sysParamRxObj.(sprintf('DL_BS_%d', current_BS_id)).OFDMParams = OFDMParams;
        sysParamRxObj.(sprintf('DL_BS_%d', current_BS_id)).dataParams = dataParams;
        sysParamRxObj.(sprintf('DL_BS_%d', current_BS_id)).all_radioResource = all_radioResource;
        sysParamRxObj.(sprintf('DL_BS_%d', current_BS_id)).txParam = txParam;
    end
end
