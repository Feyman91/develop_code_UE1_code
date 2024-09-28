function plotEVMandMER(BS_fieldnames, EVM_collection, MER_collection, numFrames)
    % plotEVMandMER - 在循环结束后绘制所有每个基站的 EVM 和 MER
    %
    % 输入参数：
    %   BS_fieldnames   - 基站字段名称列表
    %   EVM_collection  - 包含每个基站 EVM 数据的结构体
    %   MER_collection  - 包含每个基站 MER 数据的结构体
    %   frameNum        - 当前的帧号
    %   numFrames       - 总帧数，用于设置横轴的范围
    %

    persistent hFig hPlotEVM_Header hPlotEVM_Data hPlotMER_Header hPlotMER_Data;
    numBS = length(BS_fieldnames);  % 基站数量

    % 初始化图形和线条
    hFig = figure('Name', 'EVM and MER Plot', 'NumberTitle', 'off');
    
    % 创建两个 y 轴的图形
    hold on;
    yyaxis left;
    hPlotEVM_Header = gobjects(1, numBS);  % 创建一个空的句柄对象数组用于 EVM header
    hPlotEVM_Data = gobjects(1, numBS);    % 创建一个空的句柄对象数组用于 EVM data
    for i = 1:numBS
        hPlotEVM_Header(i) = plot(nan(1, numFrames), 'LineWidth', 2, 'DisplayName', [BS_fieldnames{i} ' Header EVM'], 'LineStyle', '-');
        hPlotEVM_Data(i) = plot(nan(1, numFrames), 'LineWidth', 2, 'DisplayName', [BS_fieldnames{i} ' Data EVM'], 'LineStyle', '--');
    end
    ylabel('EVM (%)');
    
    yyaxis right;
    hPlotMER_Header = gobjects(1, numBS);  % 创建一个空的句柄对象数组用于 MER header
    hPlotMER_Data = gobjects(1, numBS);    % 创建一个空的句柄对象数组用于 MER data
    for i = 1:numBS
        hPlotMER_Header(i) = plot(nan(1, numFrames), 'LineWidth', 2, 'DisplayName', [BS_fieldnames{i} ' Header MER'], 'LineStyle', '-.');
        hPlotMER_Data(i) = plot(nan(1, numFrames), 'LineWidth', 2, 'DisplayName', [BS_fieldnames{i} ' Data MER'], 'LineStyle', ':');
    end
    ylabel('MER (dB)');

    xlabel('Frame Number');
    legend('show');
    grid on;


    % 添加提示框
    yyaxis left;
    hTextAnnotation = text(numFrames * 0.7, max(ylim) * 0.8, ...
        {'Tips:', 'MER ↑ - Better', 'EVM ↓ - Better'}, ...
        'FontSize', 10, 'BackgroundColor', 'w', 'EdgeColor', 'k', 'LineWidth', 1);

    % 更新每个基站的 EVM 和 MER 数据
    for i = 1:numBS
        current_BS_field = BS_fieldnames{i};
        
        % 更新 EVM header 和 data
        yyaxis left;
        set(hPlotEVM_Header(i), 'YData', EVM_collection.(current_BS_field).header(1:numFrames));
        set(hPlotEVM_Header(i), 'XData', 1:numFrames);  % 更新横轴
        set(hPlotEVM_Data(i), 'YData', EVM_collection.(current_BS_field).data(1:numFrames));
        set(hPlotEVM_Data(i), 'XData', 1:numFrames);    % 更新横轴
        
        % 更新 MER header 和 data
        yyaxis right;
        set(hPlotMER_Header(i), 'YData', MER_collection.(current_BS_field).header(1:numFrames));
        set(hPlotMER_Header(i), 'XData', 1:numFrames);  % 更新横轴
        set(hPlotMER_Data(i), 'YData', MER_collection.(current_BS_field).data(1:numFrames));
        set(hPlotMER_Data(i), 'XData', 1:numFrames);    % 更新横轴
    end

    % 刷新图像
    drawnow;
end
