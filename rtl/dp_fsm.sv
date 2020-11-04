import dp_package::*;
import hwpe_ctrl_package::*;

module dp_fsm #(
    parameter int unsigned AXI_WORD_SIZE = 32
)(

    // global signals
    input  logic                clk_i,
    input  logic                rst_ni,
    input  logic                test_mode_i,
    input  logic                clear_i,

    // ctrl & flags
    output ctrl_streamer_t      ctrl_streamer_o,
    input  flags_streamer_t     flags_streamer_i,
    input  flags_streamer_t     flags_other_streamer_i,
    output ctrl_engine_t        ctrl_engine_o,
    input  flags_engine_t       flags_engine_i,
    output ctrl_ucode_t         ctrl_ucode_o,
    input  flags_ucode_t        flags_ucode_i,
    output ctrl_slave_t         ctrl_slave_o,
    input  flags_slave_t        flags_slave_i,
    input  ctrl_fsm_t           ctrl_i,
    output ucode_t              ucode_o
);

    state_fsm_t curr_state, next_state;

    logic unsigned [31:0] res_counter;

    logic unsigned [1:0] counter_to_3;
    logic unsigned [31:0] counter_rows;
    logic unsigned [31:0] counter_rows_3;
    logic unsigned [31:0] counter_cols;
    logic unsigned [31:0] counter_cols_3;

    logic unsigned [31:0] mat_offset_pool;
    logic unsigned [31:0] mat_offset_pool_base;
    logic unsigned [31:0] res_offset_pool;

    logic is_first;

    always_ff @(posedge clk_i or negedge rst_ni)
    begin : main_fsm_seq
        if (~rst_ni) begin
            curr_state <= FSM_IDLE;
        end
        else if (clear_i) begin
            curr_state <= FSM_IDLE;
        end
        else begin
            curr_state <= next_state;
        end
    end

    always_comb
    begin : main_fsm_comb
        // Sizes from software are converted from WORD_SIZE to AXI_WORD_SIZE (32 bit).
        // mat stream
        if (~ctrl_i.dp_pool_sel) begin
            ctrl_streamer_o.mat_source_ctrl.addressgen_ctrl.base_addr    = ctrl_i.sub_mat_base_addr + flags_ucode_i.offs[DP_UCODE_MAT_OFFS] * (WORD_SIZE_MATRIX / 8); // Address is in bytes, offset is in words.
            ctrl_streamer_o.mat_source_ctrl.addressgen_ctrl.trans_size   = ctrl_i.sub_mat_width * WORD_SIZE_MATRIX / AXI_WORD_SIZE;
            ctrl_streamer_o.mat_source_ctrl.addressgen_ctrl.line_length  = ctrl_i.sub_mat_width * WORD_SIZE_MATRIX / AXI_WORD_SIZE;
        end
        else begin
            ctrl_streamer_o.mat_source_ctrl.addressgen_ctrl.base_addr    = ctrl_i.sub_mat_base_addr + mat_offset_pool * (WORD_SIZE_MATRIX / 8); // Address is in bytes, offset is in words.
            // 3 is the pooling size. 1 is rounding to transaction size.
            //ctrl_streamer_o.mat_source_ctrl.addressgen_ctrl.trans_size   = (3 + 1) * WORD_SIZE_MATRIX / AXI_WORD_SIZE;
            ctrl_streamer_o.mat_source_ctrl.addressgen_ctrl.trans_size   = 3 * 4 * WORD_SIZE_MATRIX / AXI_WORD_SIZE;
            //ctrl_streamer_o.mat_source_ctrl.addressgen_ctrl.line_length  = (3 + 1) * WORD_SIZE_MATRIX / AXI_WORD_SIZE;
            ctrl_streamer_o.mat_source_ctrl.addressgen_ctrl.line_length  = 3 * 4 * WORD_SIZE_MATRIX / AXI_WORD_SIZE;

        end
        ctrl_streamer_o.mat_source_ctrl.addressgen_ctrl.line_stride  = '0;
        ctrl_streamer_o.mat_source_ctrl.addressgen_ctrl.feat_stride  = ctrl_i.stride;
        ctrl_streamer_o.mat_source_ctrl.addressgen_ctrl.feat_length  = 1;
        ctrl_streamer_o.mat_source_ctrl.addressgen_ctrl.feat_roll    = '0;
        ctrl_streamer_o.mat_source_ctrl.addressgen_ctrl.loop_outer   = '0;
        ctrl_streamer_o.mat_source_ctrl.addressgen_ctrl.realign_type = '1;
        // vec stream
        ctrl_streamer_o.vec_source_ctrl.addressgen_ctrl.base_addr    = ctrl_i.sub_vec_base_addr + flags_ucode_i.offs[DP_UCODE_VEC_OFFS] * (WORD_SIZE / 8); // Address is in bytes, offset is in words.
        ctrl_streamer_o.vec_source_ctrl.addressgen_ctrl.trans_size   = ctrl_i.sub_mat_height * WORD_SIZE / AXI_WORD_SIZE;
        ctrl_streamer_o.vec_source_ctrl.addressgen_ctrl.line_stride  = '0;
        ctrl_streamer_o.vec_source_ctrl.addressgen_ctrl.line_length  = ctrl_i.sub_mat_height * WORD_SIZE / AXI_WORD_SIZE;
        ctrl_streamer_o.vec_source_ctrl.addressgen_ctrl.feat_stride  = ctrl_i.stride;
        ctrl_streamer_o.vec_source_ctrl.addressgen_ctrl.feat_length  = 1;
        ctrl_streamer_o.vec_source_ctrl.addressgen_ctrl.feat_roll    = '0;
        ctrl_streamer_o.vec_source_ctrl.addressgen_ctrl.loop_outer   = '0;
        ctrl_streamer_o.vec_source_ctrl.addressgen_ctrl.realign_type = '0;
        // res stream
        if (~ctrl_i.dp_pool_sel) begin
            ctrl_streamer_o.res_sink_ctrl.addressgen_ctrl.base_addr    = ctrl_i.res_base_addr + flags_ucode_i.offs[DP_UCODE_RES_OFFS] * (WORD_SIZE / 8); // Address is in bytes, offset is in words.
            ctrl_streamer_o.res_sink_ctrl.addressgen_ctrl.trans_size   = ctrl_i.sub_mat_width * WORD_SIZE / AXI_WORD_SIZE;
            ctrl_streamer_o.res_sink_ctrl.addressgen_ctrl.line_length  = ctrl_i.sub_mat_width * WORD_SIZE / AXI_WORD_SIZE;
        end
        else begin
            ctrl_streamer_o.res_sink_ctrl.addressgen_ctrl.base_addr    = ctrl_i.res_base_addr + res_offset_pool * (WORD_SIZE_MATRIX / 8); // Address is in bytes, offset is in words.
            ctrl_streamer_o.res_sink_ctrl.addressgen_ctrl.trans_size   = 1;
            ctrl_streamer_o.res_sink_ctrl.addressgen_ctrl.line_length  = 1;
        end
        ctrl_streamer_o.res_sink_ctrl.addressgen_ctrl.line_stride  = '0;
        ctrl_streamer_o.res_sink_ctrl.addressgen_ctrl.feat_stride  = '0;
        ctrl_streamer_o.res_sink_ctrl.addressgen_ctrl.feat_length  = 1;
        ctrl_streamer_o.res_sink_ctrl.addressgen_ctrl.feat_roll    = '0;
        ctrl_streamer_o.res_sink_ctrl.addressgen_ctrl.loop_outer   = '0;
        ctrl_streamer_o.res_sink_ctrl.addressgen_ctrl.realign_type = '0;

        // ucode
        ctrl_ucode_o.accum_loop = '0; // this is not relevant for this simple accelerator, and it should be moved from
                                      // ucode to an accelerator-specific module

        // engine
        ctrl_engine_o.clear               = '0;
        ctrl_engine_o.sub_mat_width       = ctrl_i.sub_mat_width;
        ctrl_engine_o.sub_mat_height      = ctrl_i.sub_mat_height;
        ctrl_engine_o.dp_start            = 1'b0;
        ctrl_engine_o.res_to_buffer       = ctrl_i.res_to_buffer;
        ctrl_engine_o.res_transfer_enable = ctrl_i.res_transfer_enable;
        ctrl_engine_o.dp_pool_sel         = ctrl_i.dp_pool_sel;

        // slave
        ctrl_slave_o.done = '0;
        ctrl_slave_o.evt  = '0;

        // real finite-state machine
        next_state = curr_state;
        ctrl_streamer_o.mat_source_ctrl.req_start = '0;
        ctrl_streamer_o.vec_source_ctrl.req_start = '0;
        ctrl_streamer_o.res_sink_ctrl.req_start   = '0;
        ctrl_ucode_o.enable                       = '0;
        ctrl_ucode_o.clear                        = '0;

        case (curr_state)
            FSM_IDLE: begin
                ctrl_ucode_o.clear = '1;
                ctrl_engine_o.clear = '1;
                if (flags_slave_i.start) begin
                    next_state = FSM_START;
                end
            end

            FSM_START: begin
                if (ctrl_i.mat_transfer_enable) begin
                    if (flags_streamer_i.mat_source_flags.ready_start) begin
                        if (~ctrl_i.dp_pool_sel) begin
                            next_state = FSM_TRANSFER_MATRIX;
                        end
                        else begin
                            next_state = FSM_TRANSFER_MATRIX_RES_POOL;
                            //ctrl_streamer_o.res_sink_ctrl.req_start = 1'b1;
                        end
                        ctrl_streamer_o.mat_source_ctrl.req_start = 1'b1;
                    end
                    else begin
                        if (~ctrl_i.dp_pool_sel) begin
                            next_state = FSM_WAIT_MATRIX_READY;
                        end
                        else begin
                            next_state = FSM_WAIT_MATRIX_RES_READY_POOL;
                        end
                    end
                end
                else begin
                    ctrl_ucode_o.clear = '1;

                    if (flags_streamer_i.vec_source_flags.ready_start & flags_streamer_i.res_sink_flags.ready_start) begin
                        if (ctrl_i.num_of_vectors > 0) begin
                            next_state = FSM_TRANSFER_VEC;
                            ctrl_streamer_o.vec_source_ctrl.req_start = 1'b1;
                        end
                        else begin
                            next_state = FSM_DP_CALCULATE;
                            ctrl_engine_o.dp_start = 1'b1;
                            if (ctrl_i.res_transfer_enable && ctrl_i.res_streamer_enable) begin
                                ctrl_streamer_o.res_sink_ctrl.req_start = 1'b1;
                            end
                        end
                    end
                    else begin
                        next_state = FSM_WAIT_VEC_RES_READY;
                    end
                end
            end

            FSM_WAIT_MATRIX_READY: begin
                if (flags_streamer_i.mat_source_flags.ready_start) begin
                    next_state = FSM_TRANSFER_MATRIX;
                    ctrl_streamer_o.mat_source_ctrl.req_start = 1'b1;
                end
            end

            FSM_WAIT_MATRIX_RES_READY_POOL: begin
                if (counter_to_3 != 2) begin
                    if (flags_streamer_i.mat_source_flags.ready_start) begin
                        next_state = FSM_TRANSFER_MATRIX_RES_POOL;
                        ctrl_streamer_o.mat_source_ctrl.req_start = 1'b1;
                    end
                end
                else begin
                    if (flags_streamer_i.mat_source_flags.ready_start && flags_streamer_i.res_sink_flags.ready_start) begin
                        next_state = FSM_TRANSFER_MATRIX_RES_POOL;
                        ctrl_streamer_o.mat_source_ctrl.req_start = 1'b1;
                        ctrl_streamer_o.res_sink_ctrl.req_start = 1'b1;
                    end
                end
            end

            FSM_TRANSFER_MATRIX: begin
                if (flags_streamer_i.mat_source_flags.done) begin
                    next_state = FSM_UPDATE_MATRIX_INDEX;
                end
            end

            FSM_TRANSFER_MATRIX_RES_POOL: begin
                /*if (counter_to_3 == 2) begin
                    //if (flags_streamer_i.mat_source_flags.done && flags_streamer_i.res_sink_flags.done) begin
                    if (flags_streamer_i.res_sink_flags.done) begin
                        next_state = FSM_UPDATE_MATRIX_RES_INDEX_POOL;
                    end
                end
                else begin*/
                    if (flags_streamer_i.mat_source_flags.done) begin
                        next_state = FSM_UPDATE_MATRIX_RES_INDEX_POOL;
                    end
                //end
            end

            FSM_UPDATE_MATRIX_INDEX: begin
                ctrl_ucode_o.enable = 1'b1;
                if (flags_ucode_i.done) begin
                    ctrl_ucode_o.clear = '1;

                    if (flags_streamer_i.vec_source_flags.ready_start & flags_streamer_i.res_sink_flags.ready_start) begin
                        if (ctrl_i.num_of_vectors > 0) begin
                            next_state = FSM_TRANSFER_VEC;
                            ctrl_streamer_o.vec_source_ctrl.req_start = 1'b1;
                        end
                        else begin
                            next_state = FSM_DP_CALCULATE;
                            ctrl_engine_o.dp_start = 1'b1;
                            if (ctrl_i.res_transfer_enable && ctrl_i.res_streamer_enable) begin
                                ctrl_streamer_o.res_sink_ctrl.req_start = 1'b1;
                            end
                        end
                    end
                    else begin
                        next_state = FSM_WAIT_VEC_RES_READY;
                    end
                end
                else if (flags_streamer_i.mat_source_flags.ready_start) begin
                    next_state = FSM_TRANSFER_MATRIX;
                    ctrl_streamer_o.mat_source_ctrl.req_start = 1'b1;
                end
                else begin
                    next_state = FSM_WAIT_MATRIX_READY;
                end
            end

            FSM_UPDATE_MATRIX_RES_INDEX_POOL: begin
                if (counter_rows >= ctrl_i.sub_mat_height - 1 && counter_cols_3 >= ctrl_i.sub_mat_width - 3) begin
                    next_state = FSM_TERMINATE;
                end
                else begin
                    if (counter_to_3 != 0) begin
                        if (flags_streamer_i.mat_source_flags.ready_start) begin
                            next_state = FSM_TRANSFER_MATRIX_RES_POOL;
                            ctrl_streamer_o.mat_source_ctrl.req_start = 1'b1;
                        end
                        else begin
                            next_state = FSM_WAIT_MATRIX_RES_READY_POOL;
                        end
                    end
                    else begin
                        if (flags_streamer_i.mat_source_flags.ready_start && flags_streamer_i.res_sink_flags.ready_start) begin
                            next_state = FSM_TRANSFER_MATRIX_RES_POOL;
                            ctrl_streamer_o.mat_source_ctrl.req_start = 1'b1;
                            ctrl_streamer_o.res_sink_ctrl.req_start = 1'b1;
                        end
                        else begin
                            next_state = FSM_WAIT_MATRIX_RES_READY_POOL;
                        end
                    end
                end
            end

            FSM_WAIT_VEC_RES_READY: begin
                if (flags_streamer_i.vec_source_flags.ready_start & flags_streamer_i.res_sink_flags.ready_start) begin
                    if (ctrl_i.num_of_vectors > 0) begin
                        next_state = FSM_TRANSFER_VEC;
                        ctrl_streamer_o.vec_source_ctrl.req_start = 1'b1;
                    end
                    else begin
                        next_state = FSM_DP_CALCULATE;
                        ctrl_engine_o.dp_start = 1'b1;
                        if (ctrl_i.res_transfer_enable && ctrl_i.res_streamer_enable) begin
                            ctrl_streamer_o.res_sink_ctrl.req_start = 1'b1;
                        end
                    end
                end
            end

            FSM_TRANSFER_VEC: begin
                if (flags_streamer_i.vec_source_flags.done) begin
                    next_state = FSM_WAIT_VECTOR_ARRIVE;
                end
            end

            FSM_WAIT_VECTOR_ARRIVE: begin
                next_state = FSM_DP_CALCULATE;
                ctrl_engine_o.dp_start = 1'b1;
                if (ctrl_i.res_transfer_enable && ctrl_i.res_streamer_enable) begin
                    ctrl_streamer_o.res_sink_ctrl.req_start = 1'b1;
                end
            end

            FSM_DP_CALCULATE: begin
                if (flags_engine_i.dp_done) begin
                    if (ctrl_i.res_transfer_enable) begin
                        next_state = FSM_TRANSFER_RES;
                    end
                    else begin
                        next_state = FSM_UPDATE_VEC_RES_INDEX;
                    end
                end
            end

            FSM_TRANSFER_RES: begin
                if (ctrl_i.res_streamer_enable) begin
                    if (flags_streamer_i.res_sink_flags.done) begin
                        next_state = FSM_UPDATE_VEC_RES_INDEX;
                    end
                end
                else begin
                    if (flags_other_streamer_i.res_sink_flags.done) begin
                        next_state = FSM_UPDATE_VEC_RES_INDEX;
                    end
                end
            end

            FSM_UPDATE_VEC_RES_INDEX: begin
                if ((ctrl_i.num_of_vectors == 0) | (flags_ucode_i.done & ~flags_ucode_i.valid)) begin
                    ctrl_ucode_o.clear = '1;
                    next_state = FSM_TERMINATE;
                end
                else if (~flags_ucode_i.valid) begin
                    ctrl_ucode_o.enable = 1'b1;
                end
                else if (flags_streamer_i.vec_source_flags.ready_start & flags_streamer_i.res_sink_flags.ready_start) begin
                    next_state = FSM_TRANSFER_VEC;
                    ctrl_streamer_o.vec_source_ctrl.req_start = 1'b1;
                end
                else begin
                    next_state = FSM_WAIT_VEC_RES_READY;
                end
            end

            FSM_TERMINATE: begin
                // wait for the flags to be ok then go back to idle
                ctrl_engine_o.clear  = 1'b1;
                if (flags_streamer_i.mat_source_flags.ready_start & flags_streamer_i.vec_source_flags.ready_start & flags_streamer_i.res_sink_flags.ready_start) begin
                    next_state = FSM_IDLE;
                    ctrl_slave_o.done = 1'b1;
                end
            end
        endcase
    end

    always_comb
    begin
        case (curr_state)
            FSM_IDLE, FSM_START, FSM_WAIT_MATRIX_READY, FSM_TRANSFER_MATRIX, FSM_UPDATE_MATRIX_INDEX, FSM_WAIT_MATRIX_RES_READY_POOL, FSM_TRANSFER_MATRIX_RES_POOL, FSM_UPDATE_MATRIX_RES_INDEX_POOL: begin
                ucode_o = {
                    // loops & bytecode
                    UCODE_FLAT_MATRIX,
                    // ranges
                    12'b0,
                    12'b0,
                    12'b0,
                    12'b0,
                    12'b0,
                    ctrl_i.sub_mat_height[11:0]
                };

                ctrl_streamer_o.mat_vec_stream_sel = 1'b0;
            end

            default: begin
                ucode_o = {
                    // loops & bytecode
                    UCODE_FLAT_VECTORS_RESULTS,
                    // ranges
                    12'b0,
                    12'b0,
                    12'b0,
                    12'b0,
                    12'b0,
                    ctrl_i.num_of_vectors[11:0]
                };

                ctrl_streamer_o.mat_vec_stream_sel = 1'b1;
            end
        endcase
    end

    always_ff @(posedge clk_i or negedge rst_ni)
    begin : res_counter_proc
        if (~rst_ni) begin
            res_counter <= 0;
        end
        else if (clear_i) begin
            res_counter <= 0;
        end
        else begin
            // Comment: might not work when trying multiple scenario with a single vector.
            if (ctrl_i.num_of_vectors > 1) begin
                if (next_state == FSM_IDLE) begin
                    res_counter <= 0;
                end
                else if (((curr_state == FSM_DP_CALCULATE) || (curr_state == FSM_TRANSFER_RES)) && (next_state == FSM_UPDATE_VEC_RES_INDEX)) begin
                    res_counter <= res_counter + 1;
                end
            end
            else begin
                res_counter <= ctrl_i.res_buffer_index;
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni)
    begin : counter_to_3_proc
        if (~rst_ni) begin
            counter_to_3 <= 0;
        end
        else if (clear_i) begin
            counter_to_3 <= 0;
        end
        else begin
            //if (next_state == FSM_UPDATE_MATRIX_RES_INDEX_POOL && flags_streamer_i.mat_source_flags.done) begin
            if (flags_streamer_i.mat_source_flags.done) begin
                if (counter_to_3 == 2) begin
                    counter_to_3 <= 0;
                end
                else begin
                    counter_to_3 <= counter_to_3 + 1;
                end
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni)
    begin : counter_rows_cols_proc
        if (~rst_ni) begin
            counter_rows <= 0;
            counter_rows_3 <= 0;
            counter_cols <= 0;
            counter_cols_3 <= 0;
            mat_offset_pool <= 0;
            mat_offset_pool_base <= 0;
            res_offset_pool <= 0;
            is_first <= 0;
        end
        else if (clear_i) begin
            counter_rows <= 0;
            counter_rows_3 <= 0;
            counter_cols <= 0;
            counter_cols_3 <= 0;
            mat_offset_pool <= 0;
            mat_offset_pool_base <= 0;
            res_offset_pool <= 0;
            is_first <= 0;
        end
        else begin
            if (next_state == FSM_UPDATE_MATRIX_RES_INDEX_POOL) begin
                if (counter_to_3 < 2) begin
                    counter_rows <= counter_rows + 1;
                    mat_offset_pool <= mat_offset_pool + ctrl_i.sub_mat_width * 4;
                end
                else begin
                     if (~is_first) begin
                         is_first <= 1;
                     end
                     else begin
                         res_offset_pool <= res_offset_pool + 4;
                     end
                     if (counter_cols_3 < ctrl_i.sub_mat_width - 3) begin
                         counter_rows <= counter_rows - 2;
                         mat_offset_pool <= mat_offset_pool_base + 3 * 4;
                         mat_offset_pool_base <= mat_offset_pool_base + 3 * 4;
                     end
                     else begin
                         if (counter_rows < ctrl_i.sub_mat_height - 1) begin
                             counter_rows <= counter_rows + 1;
                             counter_rows_3 <= counter_rows_3 + 3;
                             mat_offset_pool <= mat_offset_pool + 3 * 4;
                             mat_offset_pool_base <= mat_offset_pool + 3 * 4;
                         end
                     end
                end

                if (counter_to_3 == 2) begin
                    if (counter_cols_3 < ctrl_i.sub_mat_width - 3) begin
                        counter_cols_3 <= counter_cols_3 + 3;
                        counter_cols <= counter_cols + 1;
                    end
                    else begin
                        if (counter_rows < ctrl_i.sub_mat_height - 1) begin
                            counter_cols_3 <= 0;
                            counter_cols <= 0;
                        end
                    end
                end
                
            end
        end
    end

    assign ctrl_engine_o.current_res = res_counter;

endmodule

