import dp_package::*;

module dp_engine
(
    // global signals
    input  logic                   clk_i,
    input  logic                   rst_ni,
    input  logic                   test_mode_i,
    // input matrix stream
    hwpe_stream_intf_stream.sink   mat_i,
    // input vector stream
    hwpe_stream_intf_stream.sink   vec_i,
    // output result stream
    hwpe_stream_intf_stream.source res_o,
    // control channel
    input  ctrl_engine_t           ctrl_i,
    output flags_engine_t          flags_o
);

    logic [0:RRAM_DOTP_HEIGHT - 1][WORD_SIZE - 1:0] dp_vector;
    logic [0:RRAM_DOTP_HEIGHT - 1][0:RRAM_DOTP_WIDTH - 1][WORD_SIZE_MATRIX - 1:0] dp_matrix;
    logic [0:RRAM_DOTP_WIDTH - 1][WORD_SIZE - 1:0] dp_result;
    logic [0:RESULTS_BUFFER_SIZE - 1][0:RRAM_DOTP_WIDTH - 1][WORD_SIZE - 1:0] dp_result_buffer;
    logic dp_idle;
    logic dp_idle_d1;

    logic mat_handshake;
    logic vec_handshake;
    logic res_handshake;

    logic unsigned [$clog2(RRAM_DOTP_WIDTH):0] mat_col_idx;
    logic unsigned [$clog2(RRAM_DOTP_HEIGHT):0] mat_row_idx;
    logic unsigned [$clog2(RRAM_DOTP_HEIGHT):0] vec_idx;
    logic unsigned [$clog2(RRAM_DOTP_WIDTH):0] res_idx;

    logic [3:0] counter;
    logic [7:0] curr_max;
    logic [7:0] final_max;

    logic [res_o.DATA_WIDTH/8-1:0] strb_pool;

    dot_product #(
        .RRAM_DOTP_HEIGHT(RRAM_DOTP_HEIGHT),
        .RRAM_DOTP_WIDTH(RRAM_DOTP_WIDTH),
        .WORD_SIZE(WORD_SIZE),
        .WORD_SIZE_MATRIX(WORD_SIZE_MATRIX)
    ) dot_product_u1 (
        .clk(clk_i),
        .start(ctrl_i.dp_start),
        .vector(dp_vector),
        .matrix(dp_matrix),
        .result(dp_result),
        .idle(dp_idle)
    );

    /*dp_pooling pooling_u1 (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .mat_i(mat_i),
        .res_o(res_o_pooling)
    );*/

    assign mat_handshake = mat_i.valid & mat_i.ready;
    assign vec_handshake = vec_i.valid & vec_i.ready;
    assign res_handshake = res_o.valid & res_o.ready;

    assign flags_o.cnt = res_idx;

    /*always_comb begin
        if (ctrl_i.dp_pool_sel == 1'b0) begin
            res_o = res_o_dp;
        end
        else begin
            res_o = res_o_pooling;
        end
    end*/

    always_comb
    begin
        if (ctrl_i.dp_pool_sel == 1'b0) begin
            res_o.strb = '1;
        end
        else begin
            //res_o.strb = strb_pool;
            //res_o.strb = 1;
            res_o.strb = '1;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni)
    begin : sampling_proc
        if (~rst_ni) begin
            dp_idle_d1 <= 1'b0;
        end
        else begin
            dp_idle_d1 <= dp_idle;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni)
    begin : mat_indices_proc
        if (~rst_ni) begin
            mat_col_idx <= 0;
            mat_row_idx <= 0;
        end
        else if (ctrl_i.clear) begin
            mat_col_idx <= 0;
            mat_row_idx <= 0;
        end
        else begin
            if (mat_handshake) begin
                if (mat_col_idx < ctrl_i.sub_mat_width - mat_i.DATA_WIDTH / WORD_SIZE_MATRIX) begin
                    mat_col_idx <= mat_col_idx + mat_i.DATA_WIDTH / WORD_SIZE_MATRIX;
                end
                else begin
                    mat_col_idx <= 0;
                    if (mat_row_idx < ctrl_i.sub_mat_height - 1) begin
                        mat_row_idx <= mat_row_idx + 1;
                    end
                    else begin
                        mat_row_idx <= 0;
                    end
                end
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni)
    begin : mat_data_proc
        integer i;

        if (~rst_ni) begin
            dp_matrix <= 0;
        end
        else begin
            // If a new matrix is starting to arrive
            if (mat_handshake & (mat_row_idx == 0) & (mat_col_idx == 0)) begin
                // Clear the currently stored matrix.
                dp_matrix <= 0;
            end

            // Store the received values.
            if (mat_handshake) begin
                for (i = 0; i < mat_i.DATA_WIDTH / WORD_SIZE_MATRIX; i++) begin
                    dp_matrix[mat_row_idx][mat_col_idx + i] <= mat_i.data[WORD_SIZE_MATRIX*i +: WORD_SIZE_MATRIX];
                end
            end
        end
    end
    //assign dp_matrix = 0;
    assign mat_i.ready = 1'b1;

    always_ff @(posedge clk_i or negedge rst_ni)
    begin : vec_index_proc
        if (~rst_ni) begin
            vec_idx <= 0;
        end
        else if (ctrl_i.clear) begin
            vec_idx <= 0;
        end
        else begin
            if (vec_handshake) begin
                if (vec_idx < ctrl_i.sub_mat_height - vec_i.DATA_WIDTH / WORD_SIZE) begin
                    vec_idx <= vec_idx + vec_i.DATA_WIDTH / WORD_SIZE;
                end
                else begin
                    vec_idx <= 0;
                end
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni)
    begin : vec_data_proc
        integer i;

        if (~rst_ni) begin
            dp_vector <= 0;
        end
        else begin
            // If a new vector is starting to arrive
            if (vec_handshake & (vec_idx == 0)) begin
                // Clear the currently stored vector.
                dp_vector <= 0;
            end

            // Store the received values.
            if (vec_handshake) begin
                for (i = 0; i < vec_i.DATA_WIDTH / WORD_SIZE; i++) begin
                    dp_vector[vec_idx + i] <= vec_i.data[WORD_SIZE*i +: WORD_SIZE];
                end
            end
        end
    end
    //assign dp_vector = 0;
    assign vec_i.ready = 1'b1;

    always_ff @(posedge clk_i or negedge rst_ni)
    begin : res_index_proc
        if (~rst_ni) begin
            res_idx <= 0;
        end
        else if (ctrl_i.clear) begin
            res_idx <= 0;
        end
        else begin
            if (res_idx == 0) begin
                if ((dp_idle == 1'b1) & (dp_idle_d1 == 1'b0)) begin
                    if (res_idx < ctrl_i.sub_mat_width - res_o.DATA_WIDTH / WORD_SIZE) begin
                        res_idx <= res_idx + res_o.DATA_WIDTH / WORD_SIZE;
                    end
                end
            end
            else begin
                if (res_handshake) begin
                    if (res_idx < ctrl_i.sub_mat_width - res_o.DATA_WIDTH / WORD_SIZE) begin
                        res_idx <= res_idx + res_o.DATA_WIDTH / WORD_SIZE;
                    end
                    else begin
                        res_idx <= 0;
                    end
                end
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni)
    begin : res_data_proc
        integer i;

        if (~rst_ni) begin
            res_o.data <= 0;
        end
        else begin
            if (ctrl_i.dp_pool_sel == 1'b0) begin
                if (res_idx == 0) begin
                    if ((dp_idle == 1'b1) & (dp_idle_d1 == 1'b0)) begin
                        for (i = 0; i < res_o.DATA_WIDTH / WORD_SIZE; i++) begin
                            if (ctrl_i.res_to_buffer) begin
                                if (dp_result_buffer[ctrl_i.current_res][res_idx + i] + dp_result[res_idx + i] > 0) begin
                                    res_o.data[WORD_SIZE*i +: WORD_SIZE] <= dp_result_buffer[ctrl_i.current_res][res_idx + i] + dp_result[res_idx + i];
                                end
                                else begin
                                    res_o.data[WORD_SIZE*i +: WORD_SIZE] <= 0;
                                end
                            end
                            else begin
                                if (dp_result[res_idx + i] > 0) begin
                                    res_o.data[WORD_SIZE*i +: WORD_SIZE] <= dp_result[res_idx + i];
                                end
                                else begin
                                    res_o.data[WORD_SIZE*i +: WORD_SIZE] <= 0;
                                end
                            end
                        end
                    end
                end
                else begin
                    if (res_handshake) begin
                        for (i = 0; i < res_o.DATA_WIDTH / WORD_SIZE; i++) begin
                            if (ctrl_i.res_to_buffer) begin
                                 if (dp_result_buffer[ctrl_i.current_res][res_idx + i] > 0) begin
                                     res_o.data[WORD_SIZE*i +: WORD_SIZE] <= dp_result_buffer[ctrl_i.current_res][res_idx + i];
                                 end
                                 else begin
                                     res_o.data[WORD_SIZE*i +: WORD_SIZE] <= 0;
                                 end
                            end
                            else begin
                                if (dp_result[res_idx + i] > 0) begin
                                    res_o.data[WORD_SIZE*i +: WORD_SIZE] <= dp_result[res_idx + i];
                                end
                                else begin
                                    res_o.data[WORD_SIZE*i +: WORD_SIZE] <= 0;
                                end
                            end
                        end
                    end
                end
            end
            else if (mat_handshake && (counter == 8)) begin
                final_max = curr_max;
                for (i = 0; i < 1; i++) begin
                    if (final_max < mat_i.data[WORD_SIZE_MATRIX*4*i +: WORD_SIZE_MATRIX*4]) begin
                        final_max = mat_i.data[WORD_SIZE_MATRIX*4*i +: WORD_SIZE_MATRIX*4];
                    end
                end
                for (i = 0; i < res_o.DATA_WIDTH / (WORD_SIZE * 2); i++) begin
                    res_o.data[WORD_SIZE*2*i +: WORD_SIZE*2] <= final_max;
                end
            end
        end
    end

    always_ff @(posedge clk_i, negedge rst_ni) begin : strb_pool_proc
        if (~rst_ni) begin
            strb_pool <= 1;
        end
        else begin
            if (ctrl_i.clear) begin
                strb_pool <= 1;
            end
            else if (res_handshake) begin
                // Rotate left.
                strb_pool <= {strb_pool[res_o.DATA_WIDTH/8-2:0], strb_pool[res_o.DATA_WIDTH/8-1]};
            end
        end
    end

    always_ff @(posedge clk_i, negedge rst_ni) begin
        integer i;
        if (~rst_ni) begin
            counter <= 0;
            curr_max <= 0;
        end
        else if (ctrl_i.dp_pool_sel == 1'b1) begin
            /*if (mat_handshake && (counter == 9 - 3)) begin
                //for (i = 0; i < mat_i.DATA_WIDTH / WORD_SIZE_MATRIX; i++) begin
                for (i = 0; i < 3; i++) begin
                    if (mat_i.data[WORD_SIZE_MATRIX*i +: WORD_SIZE_MATRIX] > curr_max) begin
                        curr_max = mat_i.data[WORD_SIZE_MATRIX*i +: WORD_SIZE_MATRIX];
                    end
                end
                //res_o <= curr_max;
            end*/
            if (mat_handshake) begin
                //counter <= counter + mat_i.DATA_WIDTH / WORD_SIZE_MATRIX;
                if (counter == 8) begin
                    counter <= 0;
                    curr_max = 0;
                end
                else begin
                    counter <= counter + 1;
                end
                //for (i = 0; i < mat_i.DATA_WIDTH / WORD_SIZE_MATRIX; i++) begin
                for (i = 0; i < 1; i++) begin
                    if (curr_max < mat_i.data[WORD_SIZE_MATRIX*4*i +: WORD_SIZE_MATRIX*4]) begin
                        curr_max = mat_i.data[WORD_SIZE_MATRIX*4*i +: WORD_SIZE_MATRIX*4];
                    end
                end
            end
        end
    end

    //assign res_o.data = 0;
    always_ff @(posedge clk_i or negedge rst_ni)
    begin : res_valid_proc
        if (~rst_ni) begin
            res_o.valid <= 1'b0;
        end
        else if ((ctrl_i.dp_pool_sel == 1'b0)) begin
            if (ctrl_i.res_transfer_enable) begin
                if ((res_idx == 0) & ((dp_idle == 1'b1) & (dp_idle_d1 == 1'b0))) begin
                    res_o.valid <= 1'b1;
                end
                else if (res_handshake & (res_idx == 0)) begin
                    res_o.valid <= 1'b0;
                end
            end
            else begin
                res_o.valid <= 1'b0;
            end
        end
        else begin
            if (mat_handshake && counter == 8) begin
                res_o.valid <= 1'b1;
            end
            else if (res_handshake) begin
                res_o.valid <= 1'b0;
            end

        end
    end
    /*always_ff @(posedge clk_i or negedge rst_ni)
    begin : res_valid_proc
        if (~rst_ni) begin
            res_o.valid <= 1'b0;
        end
        else begin
            if (counter == 9) begin
                res_o.valid <= 1'b1;
            end
            else begin
                res_o.valid <= 1'b0;
            end
        end
    end*/


    always_ff @(posedge clk_i or negedge rst_ni)
    begin : dp_done_proc
        if (~rst_ni) begin
            flags_o.dp_done <= 1'b0;
        end
        else if (ctrl_i.clear) begin
            flags_o.dp_done <= 1'b0;
        end
        else begin
            if (ctrl_i.dp_start == 1'b1) begin
                flags_o.dp_done <= 1'b0;
            end
            else if ((dp_idle == 1'b1) & (dp_idle_d1 == 1'b0)) begin
                flags_o.dp_done <= 1'b1;
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni)
    begin : dp_result_buffer_proc
        integer i;

        if (~rst_ni) begin
            dp_result_buffer <= 0;
        end
        else begin
            if ((dp_idle == 1'b1) & (dp_idle_d1 == 1'b0)) begin
                if (ctrl_i.res_to_buffer) begin
                    for (i = 0; i < RRAM_DOTP_WIDTH; i++) begin
                        dp_result_buffer[ctrl_i.current_res][i] <= dp_result_buffer[ctrl_i.current_res][i] + dp_result[i];
                    end
                end
            end
            else if (ctrl_i.res_to_buffer & ctrl_i.res_transfer_enable & res_handshake & (res_idx == 0)) begin
                dp_result_buffer[ctrl_i.current_res] <= 0;
            end
        end
    end
    //assign dp_result_buffer = 0;
endmodule

