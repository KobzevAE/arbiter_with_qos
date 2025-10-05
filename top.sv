`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
module stream_arbiter_w_qos #(
 parameter   T_DATA_WIDTH = 4,
      T_QOS__WIDTH = 2,
      STREAM_COUNT = 2,
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
typedef enum logic {
    ST_IDLE = 1'b0,
    ST_ACTIVE = 1'b1
} state_t;

state_t state;
logic [T_ID___WIDTH-1:0] selected_stream;
logic [T_QOS__WIDTH-1:0] selected_qos;
logic [T_ID___WIDTH-1:0] rr_pointer;

logic [T_ID___WIDTH-1:0] index;
logic [T_ID___WIDTH-1:0] next_stream;
logic stream_found;

always_comb begin
    logic [T_QOS__WIDTH-1:0] max_qos;
    logic [STREAM_COUNT-1:0] candidate_mask;
    

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
    
    for (int i = 0; i < STREAM_COUNT; i++) begin            // Round Robin
  
        index = (rr_pointer + i) % STREAM_COUNT;           
        
        if (candidate_mask[index]) begin
            next_stream = index;
            stream_found = 1'b1;
            break;
        end
    end
end

always_ff @(posedge clk or negedge rst_n) begin                  // fsm
    if (!rst_n) begin
        state <= ST_IDLE;
        rr_pointer <= 0;
        selected_stream <= 0;
        selected_qos <= 0;
    end else begin
        case (state)
            ST_IDLE: begin
                if (stream_found && m_ready_in) begin           // if we have candidate and master is ready
                    state <= ST_ACTIVE;
                    selected_stream <= next_stream;
                    selected_qos <= s_qos_in[next_stream];
                    rr_pointer <= next_stream;
                end
            end
            
            ST_ACTIVE: begin
                if (s_valid_in && s_ready_out && s_last_in) begin
                    state <= ST_IDLE;
                end
            end
        endcase
    end
end

always_comb begin
    if (state == ST_ACTIVE) begin
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