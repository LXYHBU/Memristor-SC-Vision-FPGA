`timescale 1ns / 1ps
module top_tb();

reg  Clk;
reg  Rst_n;
reg  uart_rx;       // 新增：模拟电脑发给FPGA的串口线
reg  [127:0]cmp_in;
wire [127:0]pwm_out;
wire uart_tx;

// 例化顶层模块
top inst_top(
    .Clk(Clk),
    .Rst_n(Rst_n),
    .uart_rx(uart_rx),  // 连接串口接收线
    .cmp_in(cmp_in),
    .pwm_out(pwm_out),
    .uart_tx(uart_tx)
);

// ==========================================
// 串口发送 Task 定义
// 波特率 115200，1个bit的时间 = 1e9 / 115200 ≈ 8681 ns
// ==========================================
localparam BIT_TIME = 8681;

task uart_send_byte;
    input [7:0] data;
    integer i;
    begin
        // 1. 发送起始位 (拉低电平)
        uart_rx = 1'b0;
        #(BIT_TIME);

        // 2. 发送8位数据位 (LSB 先发，即从最低位开始发)
        for (i = 0; i < 8; i = i + 1) begin
            uart_rx = data[i];
            #(BIT_TIME);
        end

        // 3. 发送停止位 (拉高电平)
        uart_rx = 1'b1;
        #(BIT_TIME);
        
        // 字节与字节之间稍微留一点空闲时间（非必须，但更贴近真实情况）
        #(BIT_TIME * 2); 
    end
endtask

// ==========================================
// 主仿真流程
// ==========================================
integer j;

initial begin
    // 初始化信号
    Clk = 0;
    Rst_n = 1;
    uart_rx = 1'b1;   // 串口空闲状态必须是高电平
    //#1000;
    cmp_in = 128'h4444_4444_4444_4444_4444_4444_4444_4444;
    // 系统复位
    #20 Rst_n = 0;
    #20 Rst_n = 1;
    
    // 【关键】等待 PLL 锁定。
    // 因为 top.v 里用了 PLL，仿真时 PLL 从复位到稳定输出 256M 时钟需要一定的时间。
    // 如果不等待直接发数据，系统还在复位状态，数据会被全部丢弃。
    //#50000; 
    //cmp_in = 128'h8223_8223_8223_8888_8888_8888_8888_8222;
    //#5000000
    //cmp_in = 128'h8223_8223_8223_8888_8888_8888_8888_8220;
    $display("========== UART Simulation Start ==========");
    
    // 连续发送 128 个字节的数据
    // 这里为了测试，给第 0 路占空比设为 0，第 1 路设为 1，第 127 路设为 127
    for (j = 0; j < 128; j = j + 1) begin
        uart_send_byte(j[7:0]);
    end//0~127
    

    // 等待足够长的时间，观察 128 路 PWM 更新后的波形
    #5000000; 
    for (j = 128; j < 256; j = j + 1) begin
        uart_send_byte(j[7:0]);
    end//128~255
    $display("========== UART Transmission Done ==========");
    #5000000;
    $stop; // 停止仿真
end

// 产生 50MHz 输入时钟 (周期 20ns)
always #10 Clk = ~Clk;

endmodule