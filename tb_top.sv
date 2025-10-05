`timescale 1ns/1ps

module tb_stream_arbiter_w_qos();

parameter T_DATA_WIDTH = 4;
parameter T_QOS__WIDTH = 2;
parameter STREAM_COUNT = 2;
localparam T_ID___WIDTH = $clog2(STREAM_COUNT);
logic clk;
logic rst_n;

// Input streams
logic [T_DATA_WIDTH-1:0] s_data_in [STREAM_COUNT-1:0];
logic [T_QOS__WIDTH-1:0] s_qos_in [STREAM_COUNT-1:0];
logic [STREAM_COUNT-1:0] s_last_in;
logic [STREAM_COUNT-1:0] s_valid_in;
logic [STREAM_COUNT-1:0] s_ready_out;

// Output stream
logic [T_DATA_WIDTH-1:0] m_data_out;
logic [T_QOS__WIDTH-1:0] m_qos_out;
logic [T_ID___WIDTH-1:0] m_id_out;
logic m_last_out;
logic m_valid_out;
logic m_ready_in;

// Clock generation
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

// DUT
stream_arbiter_w_qos #(
    .T_DATA_WIDTH(T_DATA_WIDTH),
    .T_QOS__WIDTH(T_QOS__WIDTH),
    .STREAM_COUNT(STREAM_COUNT),
    .T_ID___WIDTH(T_ID___WIDTH)
) dut (
    .clk(clk),
    .rst_n(rst_n),
    
    .s_data_in(s_data_in),
    .s_qos_in(s_qos_in),
    .s_last_in(s_last_in),
    .s_valid_in(s_valid_in),
    .s_ready_out(s_ready_out),
    
    .m_data_out(m_data_out),
    .m_qos_out(m_qos_out),
    .m_id_out(m_id_out),
    .m_last_out(m_last_out),
    .m_valid_out(m_valid_out),
    .m_ready_in(m_ready_in)
);

initial begin
    // Initialize
    rst_n = 0;
    m_ready_in = 1;
    s_valid_in = 0;
    s_last_in = 0;
    foreach(s_data_in[i]) begin
        s_data_in[i] = 0;
        s_qos_in[i] = 0;
    end
    
    // Reset
    #20;
    rst_n = 1;
    #10;
    
    $display("----------------- Test 1: Basic QoS Priority ------------------------");
    
    s_valid_in[0] = 1;
    s_data_in[0] = 4'hA;
    s_qos_in[0] = 2'b01; 
    s_last_in[0] = 0;
    
    s_valid_in[1] = 1;
    s_data_in[1] = 4'hB;
    s_qos_in[1] = 2'b10; 
    s_last_in[1] = 0;
    
    #10; 
    
    s_data_in[1] = 4'hD;
    s_last_in[1] = 1;
    #10;
    s_valid_in[1] = 0;
    s_valid_in[0] = 1;
    #10;
    s_data_in[0] = 4'hC;
    s_last_in[0] = 1;
    // End transactions
    #10
    s_valid_in = 0;
    s_last_in = 0;
    #20;
    
    $display("--------------Test 2: same_qos ----------------");
    
    // Both streams same qos 2=2
      s_valid_in[0] = 1;
    s_data_in[0] = 4'h9;
    s_qos_in[0] = 2'b01; 
    s_last_in[0] = 0;
    
    s_valid_in[1] = 1;
    s_data_in[1] = 4'h7;
    s_qos_in[1] = 2'b01; 
    s_last_in[1] = 0;
    
    #10; 
    
    s_data_in[0] = 4'h8;
    s_last_in[0] = 1;
    #10;
    s_valid_in[0] = 0;
    #10;
    s_data_in[1] = 4'h6;
    s_last_in[1] = 1;
    // End transactions
    #10
    s_valid_in = 0;
    s_last_in = 0;
    #20;
    
    $display("---------------- FINISH -----------------");
    $finish;
end

// Monitor
always @(posedge clk) begin    
    for (int i =0; i < STREAM_COUNT; i++) begin
      $display("Time=%0t: IN[%0d]: data=0x%h, qos=%0d, last=%0d, valid_in =%0d, ready_out=%0d \n\n", 
                $time, i, s_data_in[i], s_qos_in[i], s_last_in[i], s_valid_in[i], s_ready_out[i], s_ready_out[i]);
      $display("Time=%0t: OUT: id=%0d, qos=%0d, data=0x%h, last=%0d, valid_out =%0d, ready_in = %0d \n\n", 
                $time, m_id_out, m_qos_out, m_data_out, m_last_out, m_valid_out, m_ready_in);                   
    end
end



endmodule