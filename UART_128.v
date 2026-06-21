module UART_128 (
    input              Clk,
    input              Rst_n,
    input              uart_rx,
    output             uart_tx,
    input              locked,
    // --- RX AXI 输出接口 ---
    output             uart_rx_axis_tvalid,
    output  reg  [6:0] rx_cnt,
    output  reg        rx_update_en,
    output       [7:0] uart_rx_axis_tdata,
    // --- TX AXI 输入接口 ---
    input        [7:0] uart_tx_axis_tdata,    // 要发送的数据
    input              uart_tx_axis_tvalid,   // 发送数据有效脉冲
    output             uart_tx_axis_tready    // 发送模块就绪标志
);
//跨时钟域同步器（打两拍 消除亚稳态）
wire       uart_rxd_sync;
sync_signal #(
	.WIDTH(1),
	.N(2)
)
sync_signal_inst (
	.clk(Clk),
	.in({uart_rx}),
	.out({uart_rxd_sync})
);
//串口逻辑例化
uart uart0 (
	.clk(Clk),
	.rst(~Rst_n),
	// AXI input(tx)
	.s_axis_tdata(uart_tx_axis_tdata),
	.s_axis_tvalid(uart_tx_axis_tvalid),
	.s_axis_tready(uart_tx_axis_tready),
	// AXI output(rx)
	.m_axis_tdata(uart_rx_axis_tdata),
	.m_axis_tvalid(uart_rx_axis_tvalid),
	.m_axis_tready(1'b1),
	// uart
	.rxd(uart_rxd_sync),
	.txd(uart_tx),
	// status
	.tx_busy(),
	.rx_busy(),
	.rx_overrun_error(),
	.rx_frame_error(),
	// configuration
	.prescale(16'd278/* clk/(baut*8) */) //256MHz, 115200bps
);//2000000bps

// ==========================================
// 串口接收缓冲与状态机 (一次性收128个字节)
// ==========================================
reg [17:0] timeout_cnt; // 超时计数器

// 256MHz下，115200波特率一个字节约87us。
// 设定超时阈值为500us无数据（128,000个时钟周期），防止数据错位
always @(posedge Clk or negedge locked) begin
    if(!locked) begin
        rx_cnt       <= 7'd0;
        rx_update_en <= 1'b0;
        timeout_cnt  <= 18'd0;
    end else begin
        rx_update_en <= 1'b0; // 默认拉低，只产生单脉冲
        
        if (uart_rx_axis_tvalid) begin
            timeout_cnt <= 18'd0; // 收到新数据，清理超时计数器
            
            rx_cnt <= rx_cnt + 1'b1; // 地址自增
            
            // 当收到第128个数据时，发出统一更新脉冲
            if (rx_cnt == 7'd127) begin
                rx_update_en <= 1'b1;
            end
        end 
        else if (timeout_cnt != 18'd200_000) begin
            timeout_cnt <= timeout_cnt + 1'b1;
        end
        
        // 如果过长时间没有新数据进入，将计数器清零，防止由于干扰丢包导致下一帧错位
        if (timeout_cnt == 18'd150_000) begin
            rx_cnt <= 7'd0;
        end
    end
end
endmodule