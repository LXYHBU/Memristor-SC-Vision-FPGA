module top(
    input               Clk,        // 外部输入时钟（如50M）
    input               Rst_n,      // 外部复位，低有效
    input               uart_rx,    // UART接收
    input    [127:0]    cmp_in,     // 128路外部比较器输出
    output   [127:0]    pwm_out,    // 128路PWM输出
    output              uart_tx     // UART发送
);

////////////////////////////////// 时钟与复位 //////////////////////////////////
wire locked;
wire CLK_256M;
clk_wiz_0 inst_PLL
(
    .clk_out1(CLK_256M),       
    .resetn(Rst_n), 
    .locked(locked),    
    .clk_in1(Clk)
); 
wire Clk_100K;//选通信号
divider inst_divider_(//输入50M，输出100K 50%
    .clk_in(Clk),           
    .div_ratio(16'd500),  
    .duty_cycle(16'd250),  
    .clk_out(Clk_100K)      
);
////////////////////////////////// 串口模块 //////////////////////////////////
wire         uart_rx_axis_tvalid;
wire  [6:0]  rx_cnt;
wire         rx_update_en;
wire  [7:0]  uart_rx_axis_tdata;

wire [7:0]  monitor_tx_data;
wire        monitor_tx_valid;
wire        monitor_tx_ready;

UART_128 inst_uart(
    .Clk(CLK_256M),
    .Rst_n(1),
    .locked(locked),
    //rx
    .uart_rx(uart_rx),
    .uart_rx_axis_tvalid(uart_rx_axis_tvalid),
    .rx_cnt(rx_cnt),
    .rx_update_en(rx_update_en),
    .uart_rx_axis_tdata(uart_rx_axis_tdata),
    //tx
    .uart_tx(uart_tx),
    .uart_tx_axis_tdata (monitor_tx_data),
    .uart_tx_axis_tvalid(monitor_tx_valid),
    .uart_tx_axis_tready(monitor_tx_ready)
);

////////////////////////////////// PWM模块 //////////////////////////////////
wire pwm_update_done;
PWM #(
    .SYS_CLK_HZ(256_000_000),
    .PWM_FREQ_HZ(500_000),
    .PWM_DUTY(50)          
)inst_PWM(
    .Clk      (CLK_256M),
    .wr_en    (uart_rx_axis_tvalid),
    .wr_addr  (rx_cnt),
    .wr_data  (uart_rx_axis_tdata),
    .update_en(rx_update_en),
    .pwm_out  (pwm_out),
    .pwm_update_done(pwm_update_done)
);

////////////////////////////////// 异或模块 //////////////////////////////////
wire  [63:0]  xor_out;
XOR inst_XOR(
    .Clk(CLK_256M),
    .cmp_in(cmp_in),
    .xor_out(xor_out)
);

////////////////////////////////// 选通模块 //////////////////////////////////
wire  [31:0]  mux_out;
mux inst_mux(
    .Clk(CLK_256M),
    .sel(Clk_100K),
    .data_in(xor_out),
    .mux_out(mux_out)
);

////////////////////////////////// 计数模块（32路全统计+串口回传） //////////////////////////////////
signal_monitor #(
    .CHANNELS(32),            // 32路
    .WINDOW_CYCLES(1024)      // 统计窗口1024个(256M)周期（可调整,4微秒）
) inst_monitor (
    .clk           (CLK_256M),
    .ext_en        (pwm_update_done),
    .mux_in        (mux_out),
    .m_axis_tdata  (monitor_tx_data),
    .m_axis_tvalid (monitor_tx_valid),
    .m_axis_tready (monitor_tx_ready)
);

endmodule