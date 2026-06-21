module XOR (
    input               Clk,          // 统一用256M时钟
    //input               Rst_n,           // 同步复位
    input      [127:0]  cmp_in,            // 外部比较器异步输入
    output reg [63:0]   xor_out=64'd0      // 同步异或输出
);

// ====================== 步骤1：两级同步寄存器，消除亚稳态 ======================
reg [127:0] cmp_d1=128'd0;
reg [127:0] cmp_d2=128'd0;
always @(posedge Clk) begin
    cmp_d1 <= cmp_in;
    cmp_d2 <= cmp_d1;
end

// ====================== 步骤2：异或运算+输出打拍，滤除组合逻辑毛刺 ======================
genvar i;
generate
    for (i = 0; i < 64; i = i + 1) begin : xor_loop
        // 组合逻辑异或
        wire xor_comb = cmp_d2[2*i + 1] ^ cmp_d2[2*i];
        
        // 时序逻辑打拍输出
        always @(posedge Clk) begin
            xor_out[i] <= xor_comb;
        end
    end
endgenerate

endmodule