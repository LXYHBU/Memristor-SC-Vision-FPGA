module m_wave(//伪随机序列 0 1 概率相等
    input Clk,
    output m_seq
);
reg [19:0] m_reg=20'hFFFFF; // 20位移位寄存器（位宽=多项式最高次项（N））

always @(posedge Clk) begin
    m_reg <= {m_reg[18:0], m_reg[19] ^ m_reg[2]};
    // 本原多项式： x^20 + x^3 + 1
    // 将第20位和第3位异或后输入到第1位
end
//周期=2^N-1
assign m_seq = m_reg[19]; // 取寄存器最高位输出
endmodule
