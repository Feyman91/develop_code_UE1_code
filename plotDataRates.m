function plotDataRates(BS_fieldnames, dataRateCollection, numFrames)
    % plotDataRates - 绘制所有基站的速率和总速率
    %
    % 输入参数：
    %   BS_fieldnames       - 基站字段名称列表
    %   dataRateCollection  - 包含每个基站速率和总速率的结构体
    %   numFrames           - 总帧数，用于设置横轴的范围
    %

    % 初始化图形
    figure('Name', 'Data Rate Plot', 'NumberTitle', 'off');
    hold on;
    
    numBS = length(BS_fieldnames);  % 基站数量

    % 绘制每个基站的速率
    for i = 1:numBS
        current_BS_field = BS_fieldnames{i};
        plot(1:numFrames, dataRateCollection.(current_BS_field)(1:numFrames), 'DisplayName', current_BS_field, 'LineWidth', 2);
    end
    
    % 绘制总速率
    plot(1:numFrames, dataRateCollection.total(1:numFrames), 'k-', 'LineWidth', 2, 'DisplayName', 'Total Rate');
    
    xlabel('Frame Number');
    ylabel('Data Rate (bps)');
    legend('show');
    grid on;
    ylim([0, inf]);  % 动态调整纵轴范围
end
