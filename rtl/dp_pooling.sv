import dp_package::*;

module dp_pooling
(
    // global signals
    input  logic                   clk_i,
    input  logic                   rst_ni,
    // input matrix stream
    hwpe_stream_intf_stream.sink   mat_i,
    // output result stream
    hwpe_stream_intf_stream.source res_o
);


    logic mat_handshake;
    logic res_handshake;
    logic [3:0] counter;
    logic [7:0] curr_max;

    assign mat_handshake = mat_i.valid & mat_i.ready;
    assign res_handshake = res_o.valid & res_o.ready;

    always_comb
    begin
        res_o.strb = '1;
    end


    always_ff @(posedge clk_i, negedge rst_ni) begin
        if (~rst_ni) begin
            counter <= 0;
        end
        else begin
            if (mat_handshake && (counter == 8)) begin
                for (i = 0; i < mat_i.DATA_WIDTH / WORD_SIZE_MATRIX; i++) begin
                    if (mat_i.data[WORD_SIZE_MATRIX*i +: WORD_SIZE_MATRIX] > curr_max) begin
                        curr_max = mat_i.data[WORD_SIZE_MATRIX*i +: WORD_SIZE_MATRIX];
                    end
                end
                res_o <= curr_max;
                curr_max <= 0;
                counter <= 0;
            end
            else if (mat_handshake) begin
                counter <= counter + mat_i.DATA_WIDTH / WORD_SIZE_MATRIX;
                for (i = 0; i < mat_i.DATA_WIDTH / WORD_SIZE_MATRIX; i++) begin
                    if (curr_max < mat_i.data[WORD_SIZE_MATRIX*i +: WORD_SIZE_MATRIX]) begin
                        curr_max = mat_i.data[WORD_SIZE_MATRIX*i +: WORD_SIZE_MATRIX];
                    end
                end
            end
        end
    end
    
    always_ff @(posedge clk_i or negedge rst_ni)
    begin : res_valid_proc
        if (~rst_ni) begin
            res_o.valid <= 1'b0;
        end
        else begin
            if (counter == 8) begin
                res_o.valid <= 1'b1;
            end
            else begin
                res_o.valid <= 1'b0;
            end
        end
    end

endmodule

