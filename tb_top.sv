`timescale 1ns/1ps

module tb_stream_arbiter_w_qos();

parameter T_DATA_WIDTH = 4;
parameter T_QOS__WIDTH = 2;
parameter STREAM_COUNT = 3;
localparam T_ID___WIDTH = $clog2(STREAM_COUNT);

//========================//
parameter T_PACK_NUM  = 4;
parameter T_TOTAL_NUM = 8;
parameter SEED        = 1; 

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

//========================//
logic [STREAM_COUNT-1:0] transaction_mask;
logic [STREAM_COUNT-1:0][T_PACK_NUM-1:0][T_DATA_WIDTH-1:0] data_buf;


// Clock generation
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end
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

//========================//
task init_ports ();
   // Initialize
    rst_n      = 0;
    m_ready_in = 1;
    foreach(s_data_in[i]) begin
        s_data_in [i] = 0;
        s_qos_in  [i] = 0;
        s_valid_in[i] = 0;
        s_last_in [i] = 0;
    end
    // Reset
    @(posedge clk);
    @(posedge clk);
    rst_n = 1;
    @(posedge clk);
endtask

//========================//
task automatic send_transaction ();
    input [T_PACK_NUM  -1:0][T_DATA_WIDTH-1:0] data;
    input [T_QOS__WIDTH-1:0] qos;
    input [T_ID___WIDTH-1:0] id ;

    int i = 0;
    
    s_valid_in [id] = 1;
    s_qos_in   [id] = qos;
//     for (int i=0;i<T_PACK_NUM;i++) begin
//         wait (s_ready_out[id]);
    while (i<T_PACK_NUM) begin
        s_data_in  [id] = data[i];
        
        if (i==T_PACK_NUM-1) begin 
            s_last_in[id] = 1;
            @(posedge clk);
            break;
        end
        @(posedge clk);
        if (s_ready_out[id]) i++;
    end
    
//     @(posedge clk);
    s_data_in  [id] = 'h0;
    s_valid_in [id] =   0;
    s_qos_in   [id] = 'h0;
    s_last_in  [id] =   0;
    @(posedge clk);
endtask

initial begin

    init_ports ();
    
    for (int i=0;i<T_TOTAL_NUM;i++) begin
        for (int j=0;j<STREAM_COUNT;j++) begin
            transaction_mask = (i+j);
            for (int k=0;k<T_PACK_NUM;k++) data_buf[j][k] = $urandom(SEED+i+j+k);
//             for (int l=0;l<STREAM_COUNT;l++) fork if (transaction_mask[l]) send_transaction (data_buf[l],$urandom(SEED+i+j+l),l);join
            fork
                if (transaction_mask[0]) begin send_transaction (data_buf[0],$urandom(SEED+i+j+0),0); end
                if (transaction_mask[1]) begin send_transaction (data_buf[1],$urandom(SEED+i+j+1),1); end
                if (transaction_mask[2]) begin send_transaction (data_buf[2],$urandom(SEED+i+j+2),2); end
            join
        end
    end
$display("---------------- FINISH -----------------");
    $finish;
end
  int transaction_count = 0;
// Monitor
always @(posedge clk) begin
    // Monitor completed output transactions
    if (m_valid_out && m_ready_in) begin
        $display("TX%0d: OUT id=%0d, data=0x%h, qos=%0d, last=%b @%0t", 
                transaction_count++, m_id_out, m_data_out, m_qos_out, m_last_out, $time);
    end

    // Monitor input handshakes
    for (int i = 0; i < STREAM_COUNT; i++) begin
        if (s_valid_in[i] && s_ready_out[i]) begin
            $display("      IN[%0d]: data=0x%h, qos=%0d, last=%b", 
                    i, s_data_in[i], s_qos_in[i], s_last_in[i]);
        end
    end
    
end
endmodule