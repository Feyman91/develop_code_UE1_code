function plotCFO(BS_fieldnames, CFO_collection, numFrames)
    % plotCFO - 在循环结束后绘制每个基站的 CFO 估计值
    %
    % 输入参数：
    %   BS_fieldnames       - 基站字段名称列表
    %   CFO_collection      - 包含每个基站 CFO 估计值的数据结构
    %   numFrames           - 总帧数，用于设置横轴的范围

    persistent hFig hPlotBS;  
    numBS = length(BS_fieldnames);  % 基站数量
    
     % 初始化图形
    hFig = figure('Name', 'CFO Estimation Plot', 'NumberTitle', 'off');
    hold on;
    
    hPlotBS = gobjects(1, numBS);
    % 绘制每个基站的 CFO 估计值
    for i = 1:numBS
        hPlotBS(i) = plot(1:numFrames, CFO_collection.(BS_fieldnames{i})(1:numFrames), 'LineWidth', 2, 'DisplayName', [BS_fieldnames{i} ' CFO']);
    end

    xlabel('Frame Number');
    ylabel('CFO Estimation (Hz)');
    title('Carrier Frequency Offset (CFO) Estimation per Frame');
    legend('show');
    grid on;

    % 创建嵌套图展示最后20帧的结果
    lastNFrames = 20;  % 最后20帧
    ax2 = axes('Position', [0.54, 0.27, 0.3, 0.3]);  % 在图中创建嵌套小图
    box on;  % 添加边框
    hold on;
    for i = 1:numBS
        plot(ax2, numFrames-lastNFrames+1:numFrames, CFO_collection.(BS_fieldnames{i})(numFrames-lastNFrames+1:numFrames), ...
            'LineWidth', 2, 'DisplayName', [BS_fieldnames{i} ' Last 20 Frames']);
    end
    xlabel('Frame Number');
    ylabel('CFO (Hz)');
    grid on;

end