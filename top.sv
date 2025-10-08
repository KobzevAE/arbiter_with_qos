module stream_arbiter_w_qos #(
 parameter   T_DATA_WIDTH = 4,
      T_QOS__WIDTH = 2,
      STREAM_COUNT = 3,
      T_ID___WIDTH = $clog2(STREAM_COUNT)
)(
 input logic clk,
 input logic rst_n,

 input logic [T_DATA_WIDTH-1:0] s_data_in [STREAM_COUNT-1:0],
 input logic [T_QOS__WIDTH-1:0] s_qos_in [STREAM_COUNT-1:0],            
 input logic [STREAM_COUNT-1:0] s_last_in,                            
 input logic [STREAM_COUNT-1:0] s_valid_in,
 output logic [STREAM_COUNT-1:0] s_ready_out,

 output logic [T_DATA_WIDTH-1:0] m_data_out,
 output logic [T_QOS__WIDTH-1:0] m_qos_out,
 output logic [T_ID___WIDTH-1:0] m_id_out,
 output logic m_last_out,
 output logic m_valid_out,
 input logic m_ready_in
 
);

logic [T_ID___WIDTH-1:0] selected_stream;
logic [T_QOS__WIDTH-1:0] selected_qos;
logic [T_ID___WIDTH-1:0] rr_pointer;

logic [T_ID___WIDTH-1:0] index;
logic [T_ID___WIDTH-1:0] next_stream;
logic stream_found;

logic [T_QOS__WIDTH-1:0] max_qos;
logic [STREAM_COUNT-1:0] candidate_mask;

//assign m_last_o = s_last_i ? 1'b1 : 1'b0;  

//assign m_valid_o = s_valid_i ? 1'b1 : 1'b0;

always_comb begin    
    max_qos = 0;                                               // finding the maximum qos
    for (int i = 0; i < STREAM_COUNT; i++) begin
        if (s_valid_in[i] && s_qos_in[i] != 0) begin
            if (s_qos_in[i] > max_qos) begin
                max_qos = s_qos_in[i];
            end
        end
    end
    
    candidate_mask = 0;
    for (int i = 0; i < STREAM_COUNT; i++) begin
        if (s_valid_in[i]) begin
            if (max_qos != 0) begin                             // select streams with maximum qos or zero qos

                if (s_qos_in[i] == max_qos || s_qos_in[i] == 0) begin
                    candidate_mask[i] = 1'b1;
                end
            end else begin

                if (s_qos_in[i] == 0) begin
                    candidate_mask[i] = 1'b1;
                end
            end
        end
    end
    
    stream_found = 1'b0;
    next_stream = rr_pointer;
    index = 0;
    for (int i = 0; i < STREAM_COUNT; i++) begin            // Round Robin
  
        index =i; //(rr_pointer + i) % STREAM_COUNT;           
        
        if (candidate_mask[index]) begin
            next_stream = index;
            stream_found = 1'b1;
            break;
        end
    end
end

always_ff @(posedge clk or negedge rst_n) begin                  // fsm
    if (!rst_n) begin

        rr_pointer <= 0;
        selected_stream <= 0;
        selected_qos <= 0;
    end else begin
                if (stream_found && m_ready_in) begin           // if we have candidate and master is ready

                    selected_stream <= next_stream;
                    selected_qos <= s_qos_in[next_stream];
                    rr_pointer <= next_stream;
                end
                else begin
                    rr_pointer <= 0;
                    selected_stream <= 0;
                    selected_qos <= 0;

                end

    end
end

always_comb begin                                                        // output
    if (stream_found) begin
        m_valid_out = s_valid_in[selected_stream];
        m_data_out = s_data_in[selected_stream];
        m_last_out = s_last_in[selected_stream];
        m_id_out = selected_stream;
        m_qos_out = selected_qos;
        
        for (int i = 0; i < STREAM_COUNT; i++) begin
            s_ready_out[i] = (i == selected_stream) ? m_ready_in : 1'b0;
        end
    end else begin
        m_valid_out = 1'b0;
        m_data_out = 0;
        m_last_out = 1'b0;
        m_id_out = 0;
        m_qos_out = 0;
        s_ready_out = 0;
    end
end

endmodule