function dynamicPlotting(BS_fieldnames, dataRateCollection, RSSI_collection, EVM_collection, MER_collection, numFrames)
    % dynamicPlotting - 动态绘制 Data Rate, RSSI, EVM, MER
    %
    % 输入参数：
    %   BS_fieldnames       - 基站字段名称列表
    %   dataRateCollection  - 包含每个基站速率和总速率的结构体
    %   RSSI_collection     - 包含每个基站 RSSI 数据的结构体
    %   EVM_collection      - 包含每个基站 EVM 数据的结构体
    %   MER_collection      - 包含每个基站 MER 数据的结构体
    %   numFrames           - 总帧数

    % 初始化绘图对象
    fprintf('Start plotting...\n');
    
    % 循环遍历所有帧，动态绘制速率、RSSI、EVM和MER
    for frameNum = 1:numFrames
        % 动态绘制 Data Rate
        plotDataRates(BS_fieldnames, dataRateCollection, frameNum, numFrames);
        
        % 动态绘制 RSSI
        plotRSSI(BS_fieldnames, RSSI_collection, frameNum, numFrames);

        % 动态绘制 EVM 和 MER
        plotEVMandMER(BS_fieldnames, EVM_collection, MER_collection, frameNum, numFrames);

    end
    
    fprintf('plotting complete!\n');
end
