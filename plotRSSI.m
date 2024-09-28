function plotRSSI(BS_fieldnames, RSSI_collection, numFrames)
    % plotRSSI - 在循环结束后绘制所有 RSSI 数据
    %
    persistent hFig hPlotBS;  
    numBS = length(BS_fieldnames);

    % 初始化图形
    hFig = figure('Name', 'RSSI Plot', 'NumberTitle', 'off');
    hold on;
    
    hPlotBS = gobjects(1, numBS);
    for i = 1:numBS
        hPlotBS(i) = plot(1:numFrames, RSSI_collection.(BS_fieldnames{i})(1:numFrames), 'LineWidth', 2, 'DisplayName', BS_fieldnames{i});
    end

    xlabel('Frame Number');
    ylabel('RSSI (dBm)');
    legend('show');
    grid on;
end
