module mux (
    input               Clk,         // 统一用256M时钟
    input               sel,         // 新增：外部输入的选通信号 (对应 Clk_100K)
    input      [63:0]   data_in,     // 异或模块输出
    output reg [31:0]   mux_out=0    // 选通输出
);

// ====================== 步骤1：外部选通信号同步化（消除异步亚稳态风险） ======================
// 将外部的100KHz信号同步到256MHz时钟域
reg sel_d1 = 1'b0;
reg sel_d2 = 1'b0;

always @(posedge Clk) begin
    sel_d1 <= sel;
    sel_d2 <= sel_d1;
end

wire sel_sync = sel_d2;  // 使用同步后的信号作为最终的选通控制

// ====================== 步骤2：输入数据打拍 ======================
reg [63:0] data_d1 = 64'd0;
always @(posedge Clk) begin
    data_d1 <= data_in;
end

// ====================== 步骤3：选通运算+输出打拍 ======================
genvar j;
generate
    for (j = 0; j < 32; j = j + 1) begin : mux_loop
        // 组合逻辑选通 (使用同步后的 sel_sync)
        wire mux_comb = sel_sync ? data_d1[2*j] : data_d1[2*j + 1];
        
        // 时序逻辑打拍输出
        always @(posedge Clk) begin
            mux_out[j] <= mux_comb;
        end
    end
endgenerate

endmodule