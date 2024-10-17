% 运行本文件来中断USRP的持续信号处理
% 初始化共享文件（存储 flag 用）
flagFile = 'interrupt_process_flag.bin';

% 确保共享文件存在
if ~isfile(flagFile)
    error('共享文件不存在，请确保接收信号处理程序已创建该文件。');
end

% 创建内存映射文件对象
m = memmapfile(flagFile, 'Writable', true, 'Format', 'int32');

% 将 flag 修改为 0，通知接收信号处理程序停止处理
m.Data(1) = 0;

disp('停止信号已发送。');
