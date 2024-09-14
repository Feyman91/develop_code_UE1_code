function plotDataRates(BS_fieldnames, dataRateCollection, frameNum, numFrames)
    % plotDataRates - 动态绘制每个基站以及总速率
    %
    % 输入参数：
    %   BS_fieldnames       - 基站字段名称列表
    %   dataRateCollection  - 包含每个基站速率和总速率的结构体
    %   frameNum            - 当前的帧号
    %   numFrames           - 总帧数，用于设置横轴的范围
    %

    persistent hFig hPlotBS hPlotTotal;  % 使用 persistent 变量避免每次都重新创建图像
    numBS = length(BS_fieldnames);  % 基站数量

    % 第一次调用时，初始化图形和线条
    if frameNum == 1
        hFig = figure('Name', 'Data Rate Plot', 'NumberTitle', 'off');
        hold on;

        % 初始化每个基站的线条
        hPlotBS = gobjects(1, numBS);  % 创建一个空的句柄对象数组
        for i = 1:numBS
            hPlotBS(i) = plot(nan(1, numFrames), 'DisplayName', BS_fieldnames{i});
        end

        % 初始化总速率线条
        hPlotTotal = plot(nan(1, numFrames), 'k-', 'LineWidth', 2, 'DisplayName', 'Total Rate');
        
        xlabel('Frame Number');
        ylabel('Data Rate (bps)');
        legend('show');
        grid on;
        ylim([0, inf]);  % 动态调整纵轴范围
    end

    % 更新每个基站的数据
    for i = 1:numBS
        current_BS_field = BS_fieldnames{i};
        % 获取每个基站的速率值并更新图像
        set(hPlotBS(i), 'YData', dataRateCollection.(current_BS_field)(1:frameNum));
        set(hPlotBS(i), 'XData', 1:frameNum);  % 更新横轴
    end

    % 更新总速率的数据
    set(hPlotTotal, 'YData', dataRateCollection.total(1:frameNum));
    set(hPlotTotal, 'XData', 1:frameNum);  % 更新横轴

    % 刷新图像
    drawnow;
end
