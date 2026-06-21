module signal_monitor #(
    parameter CHANNELS      = 32,
    parameter WINDOW_CYCLES = 1024
)(
    input                clk,
    input                ext_en,
    input       [31:0]   mux_in,
    
    output reg  [7:0]    m_axis_tdata = 8'd0,
    output reg           m_axis_tvalid = 1'b0,
    input                m_axis_tready
);

// ====================== 参数定义 ======================
localparam CNT_WIDTH = $clog2(WINDOW_CYCLES + 1);
localparam CH_WIDTH  = $clog2(CHANNELS);
localparam MULT_WIDTH = CNT_WIDTH + 8;

// ====================== 1. 输入同步 ======================
reg [31:0] mux_in_d1 = 32'd0;
reg [31:0] mux_in_d2 = 32'd0;
always @(posedge clk) begin
    mux_in_d1 <= mux_in;
    mux_in_d2 <= mux_in_d1;
end

// ====================== 2. 使能同步 ======================
reg ext_en_d1 = 1'b0;
reg ext_en_d2 = 1'b0;
always @(posedge clk) begin
    ext_en_d1 <= ext_en;
    ext_en_d2 <= ext_en_d1;
end
wire en_trigger = ext_en_d1 && !ext_en_d2;

// ====================== 3. 状态机定义 ======================
localparam INIT   = 0;
localparam IDLE   = 1;
localparam COUNT  = 2;
localparam OUTPUT = 3;

reg [1:0] state = IDLE;
reg [CNT_WIDTH-1:0] window_cnt = 0;
reg [CNT_WIDTH-1:0] high_cnt_arr[0:31];
reg [CH_WIDTH-1:0]  ch_idx = 0;
reg [MULT_WIDTH-1:0] mult_result;

// ====================== 初始化 ======================
reg [4:0] init_cnt = 5'd0; // 【复用】一个计数器同时初始化两个数组
// ====================== 状态机 ======================
integer i;
always @(posedge clk) begin
    case(state)
		  INIT:begin
					high_cnt_arr[init_cnt] = 'd0;
				   init_cnt <= init_cnt + 'd1;
					if(init_cnt == 'd31) begin
                state <= IDLE;
                init_cnt <= 'd0;
					 end
        end
        IDLE: begin
            m_axis_tvalid <= 0;
            window_cnt <= 0;
            ch_idx <= 0;
            for(i=0; i<32; i=i+1)
                high_cnt_arr[i] <= 0;
            
            if(en_trigger)
                state <= COUNT;
        end

        COUNT: begin
            window_cnt <= window_cnt + 1;
            for(i=0; i<32; i=i+1)
                if(mux_in_d2[i])
                    high_cnt_arr[i] <= high_cnt_arr[i] + 1;
            
            if(window_cnt == WINDOW_CYCLES - 1) begin
                state <= OUTPUT;
                ch_idx <= 0;
            end
        end

        OUTPUT: begin
            mult_result   <= high_cnt_arr[ch_idx] * 8'd255;
            m_axis_tdata  <= mult_result >> 10;
            m_axis_tvalid <= 1;

            if(m_axis_tvalid && m_axis_tready) begin
                m_axis_tvalid <= 0;
                if(ch_idx == 31) begin
                    state <= IDLE;
                    ch_idx <= 0;
                end else begin
                    ch_idx <= ch_idx + 1;
                end
            end
        end
    endcase
end

endmodule