function plotRSSI(BS_fieldnames, RSSI_collection, frameNum, numFrames)
    % plotRSSI - 动态绘制每个基站的 RSSI
    %
    % 输入参数：
    %   BS_fieldnames       - 基站字段名称列表
    %   RSSI_collection     - 包含每个基站 RSSI 数据的结构体
    %   frameNum            - 当前的帧号
    %   numFrames           - 总帧数，用于设置横轴的范围
    %

    persistent hFig hPlotBS;  % 使用 persistent 变量避免每次都重新创建图像
    numBS = length(BS_fieldnames);  % 基站数量

    % 第一次调用时，初始化图形和线条
    if frameNum == 1
        hFig = figure('Name', 'RSSI Plot', 'NumberTitle', 'off');
        hold on;

        % 初始化每个基站的线条
        hPlotBS = gobjects(1, numBS);  % 创建一个空的句柄对象数组
        for i = 1:numBS
            hPlotBS(i) = plot(nan(1, numFrames), 'LineWidth', 2,'DisplayName', BS_fieldnames{i});
        end

        xlabel('Frame Number');
        ylabel('RSSI (dBm)');
        legend('show');
        grid on;
        % ylim([-inf, 50]);  % 设置RSSI的纵轴范围 (通常 RSSI 是负值)
    end

    % 更新每个基站的数据
    for i = 1:numBS
        current_BS_field = BS_fieldnames{i};
        % 获取每个基站的 RSSI 值并更新图像
        set(hPlotBS(i), 'YData', RSSI_collection.(current_BS_field)(1:frameNum));
        set(hPlotBS(i), 'XData', 1:frameNum);  % 更新横轴
    end

    % 刷新图像
    drawnow;
end
