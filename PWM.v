module PWM #(
    parameter SYS_CLK_HZ  = 256_000_000,
    parameter PWM_FREQ_HZ = 1_000_000, // 这里改频率，自动适配
    parameter PWM_DUTY    = 50
)(
    input  wire             Clk,
    input  wire             wr_en,
    input  wire [6:0]       wr_addr,
    input  wire [7:0]       wr_data, // 【固定】8位数据输入，和UART一致
    input  wire             update_en,
    
    output reg  [127:0]     pwm_out = 128'd0,
    output reg              pwm_update_done = 1'b0
);

// ====================== 【关键修复】自动计算位宽 ======================
localparam PERIOD_CNT = SYS_CLK_HZ / PWM_FREQ_HZ;
localparam CNT_WIDTH  = $clog2(PERIOD_CNT + 1); // 自动算需要多少位
localparam INITIAL_DUTY_CNT = (PERIOD_CNT * PWM_DUTY) / 100;

// ====================== 状态机定义 ======================
localparam INIT   = 2'd0;
localparam IDLE   = 2'd1;
reg [1:0] state = INIT;
reg [6:0] init_cnt = 7'd0;

// ====================== 寄存器声明（用自动计算的位宽） ======================
reg [CNT_WIDTH-1:0] counter = 'd0;
reg [7:0]           duty_regs_shadow [0:127]; // 【固定8位】存UART发来的0~255
reg [CNT_WIDTH-1:0] duty_regs_active [0:127]; // 【自动位宽】实际比较用
reg update_req = 1'b0;

// ====================== 【新增】8位占空比转实际计数值的函数 ======================
function [CNT_WIDTH-1:0] duty_to_cnt;
    input [7:0] duty;
    begin
        duty_to_cnt = (duty * PERIOD_CNT) >> 8; // 0~255 → 0~PERIOD_CNT
    end
endfunction

// ====================== 状态机核心逻辑 ======================
integer j;
always @(posedge Clk) begin
    case(state)
        INIT: begin
            // 初始化影子寄存器为50%对应的8位值（127）
            duty_regs_shadow[init_cnt] <= 8'd127;
            // 初始化工作寄存器为实际计数值
            duty_regs_active[init_cnt] <= INITIAL_DUTY_CNT;
            
            init_cnt <= init_cnt + 7'd1;
            counter <= 'd0;
            update_req <= 1'b0;
            pwm_update_done <= 1'b0;
            
            if(init_cnt == 7'd127) begin
                state <= IDLE;
                init_cnt <= 7'd0;
            end
        end

        IDLE: begin
            pwm_update_done <= 1'b0;
            
            // 1. 影子寄存器：直接存UART发来的8位数据
            if(wr_en) begin
                duty_regs_shadow[wr_addr] <= wr_data;
            end
            
            // 2. 全局共享计数器（用自动位宽）
            if(counter >= PERIOD_CNT - 1'd1) begin
                counter <= 'd0;
            end else begin
                counter <= counter + 1'd1;
            end
            
            // 3. 更新逻辑
            if(update_en) begin
                update_req <= 1'b1; 
            end
            if(update_req && (counter == 'd0)) begin
                update_req <= 1'b0;
                for(j = 0; j < 128; j = j + 1) begin
                    // 【关键】更新时用函数转成实际计数值
                    duty_regs_active[j] <= duty_to_cnt(duty_regs_shadow[j]);
                end
                pwm_update_done <= 1'b1;
            end
        end

        default: state <= INIT;
    endcase
end

// ====================== 128路输出比较逻辑 ======================
genvar i;
generate
    for (i = 0; i < 128; i = i + 1) begin : pwm_cmp
        always @(posedge Clk) begin
            pwm_out[i] <= (counter < duty_regs_active[i]) ? 1'b1 : 1'b0;
        end
    end
endgenerate

endmodule