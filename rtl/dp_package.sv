import hwpe_stream_package::*;

package dp_package;

    parameter int unsigned RRAM_DOTP_HEIGHT    = 4;
    parameter int unsigned RRAM_DOTP_WIDTH     = 4;
    parameter int unsigned WORD_SIZE           = 16;
    parameter int unsigned WORD_SIZE_MATRIX    = 8;
    parameter int unsigned RESULTS_BUFFER_SIZE = 2;

    // registers in register file
    parameter int unsigned DP_REG_DP_ENABLE                  = 0;
    parameter int unsigned DP_REG_DP0_MAT_HEIGHT             = 1;
    parameter int unsigned DP_REG_DP0_NUM_OF_VECTORS         = 2;
    parameter int unsigned DP_REG_DP0_MAT_WIDTH              = 3;
    parameter int unsigned DP_REG_DP0_SUB_MAT_HEIGHT         = 4;
    parameter int unsigned DP_REG_DP0_SUB_MAT_WIDTH          = 5;
    parameter int unsigned DP_REG_DP0_SUB_MAT_BASE_ADDR      = 6;
    parameter int unsigned DP_REG_DP0_SUB_VEC_BASE_ADDR      = 7;
    parameter int unsigned DP_REG_DP0_RES_BASE_ADDR          = 8;
    parameter int unsigned DP_REG_DP0_MAT_TRANSFER_ENABLE    = 9;
    parameter int unsigned DP_REG_DP0_RES_TO_BUFFER          = 10;
    parameter int unsigned DP_REG_DP0_RES_TRANSFER_ENABLE    = 11;
    parameter int unsigned DP_REG_DP1_MAT_HEIGHT             = 12;
    parameter int unsigned DP_REG_DP1_NUM_OF_VECTORS         = 13;
    parameter int unsigned DP_REG_DP1_MAT_WIDTH              = 14;
    parameter int unsigned DP_REG_DP1_SUB_MAT_HEIGHT         = 15;
    parameter int unsigned DP_REG_DP1_SUB_MAT_WIDTH          = 16;
    parameter int unsigned DP_REG_DP1_SUB_MAT_BASE_ADDR      = 17;
    parameter int unsigned DP_REG_DP1_SUB_VEC_BASE_ADDR      = 18;
    parameter int unsigned DP_REG_DP1_RES_BASE_ADDR          = 19;
    parameter int unsigned DP_REG_DP1_MAT_TRANSFER_ENABLE    = 20;
    parameter int unsigned DP_REG_DP1_RES_TO_BUFFER          = 21;
    parameter int unsigned DP_REG_DP1_RES_TRANSFER_ENABLE    = 22;
    parameter int unsigned DP_REG_ADD_ENABLE                 = 23;
    parameter int unsigned DP_REG_DP0_RES_BUFFER_INDEX       = 24;
    parameter int unsigned DP_REG_DP1_RES_BUFFER_INDEX       = 25;
    parameter int unsigned DP_REG_DP_POOL_SEL                = 26;
    parameter int unsigned DP_REG_SUB_MAT_WIDTH_DIV3         = 27;
    parameter int unsigned DP_REG_DP_STRIDE                  = 28;
    
    parameter int unsigned DP_REG_NUM_REGS                   = 29;

    // microcode offset indeces -- this should be aligned to the microcode compiler of course!
    parameter int unsigned DP_UCODE_MAT_OFFS = 0;
    parameter int unsigned DP_UCODE_VEC_OFFS = 1;
    parameter int unsigned DP_UCODE_RES_OFFS = 2;

    parameter int unsigned DP_UCODE_NUM_RW_REGS = 3;

    // microcode mnemonics -- this should be aligned to the microcode compiler of course!
    parameter int unsigned DP_UCODE_MNEM_MAT_HEIGHT     = 3 - DP_UCODE_NUM_RW_REGS;
    parameter int unsigned DP_UCODE_MNEM_NUM_OF_VECTORS = 4 - DP_UCODE_NUM_RW_REGS;
    parameter int unsigned DP_UCODE_MNEM_MAT_WIDTH      = 5 - DP_UCODE_NUM_RW_REGS;
    parameter int unsigned DP_UCODE_MNEM_SUB_MAT_HEIGHT = 6 - DP_UCODE_NUM_RW_REGS;
    parameter int unsigned DP_UCODE_NUM_RO_REGS = 4;

    // microcode compiled code
    parameter logic [223:0] UCODE_FLAT_MATRIX          = 224'h00000000000100000000000000000000000000000000000000000405; // See code in matrix.yml
    parameter logic [223:0] UCODE_FLAT_VECTORS_RESULTS = 224'h00000000000200000000000000000000000000000000000000222c23; // See code in vectors_results.yml

    typedef struct packed {
        logic clear;
        logic unsigned [31:0] sub_mat_width;
        logic unsigned [31:0] sub_mat_height;
        logic dp_start;
        logic res_to_buffer;
        logic res_transfer_enable;
        logic dp_pool_sel;
        logic unsigned [31:0] current_res;
    } ctrl_engine_t;

    typedef struct packed {
        logic unsigned [$clog2(RRAM_DOTP_WIDTH):0] cnt;
        logic dp_done;
    } flags_engine_t;

    typedef struct packed {
        hwpe_stream_package::ctrl_sourcesink_t mat_source_ctrl;
        hwpe_stream_package::ctrl_sourcesink_t vec_source_ctrl;
        hwpe_stream_package::ctrl_sourcesink_t res_sink_ctrl;
        logic mat_vec_stream_sel;
    } ctrl_streamer_t;

    typedef struct packed {
        hwpe_stream_package::flags_sourcesink_t mat_source_flags;
        hwpe_stream_package::flags_sourcesink_t vec_source_flags;
        hwpe_stream_package::flags_sourcesink_t res_sink_flags;
    } flags_streamer_t;

    typedef struct packed {
        logic unsigned [31:0] sub_mat_width;
        logic unsigned [31:0] sub_mat_height;
        logic unsigned [31:0] num_of_vectors;
        logic unsigned [31:0] sub_mat_base_addr;
        logic unsigned [31:0] sub_vec_base_addr;
        logic unsigned [31:0] res_base_addr;
        logic unsigned [31:0] res_buffer_index;
        logic unsigned [31:0] sub_mat_width_div3;
        logic unsigned [15:0] stride;
        logic mat_transfer_enable;
        logic res_to_buffer;
        logic res_transfer_enable;
        logic res_streamer_enable;
        logic dp_pool_sel;
    } ctrl_fsm_t;

    typedef enum {
        FSM_IDLE,
        FSM_START,
        FSM_WAIT_MATRIX_READY,
        FSM_TRANSFER_MATRIX,
        FSM_UPDATE_MATRIX_INDEX,
        FSM_WAIT_VEC_RES_READY,
        FSM_TRANSFER_VEC,
        FSM_WAIT_VECTOR_ARRIVE,
        FSM_DP_CALCULATE,
        FSM_TRANSFER_RES,
        FSM_UPDATE_VEC_RES_INDEX,
        FSM_TERMINATE,
        FSM_WAIT_MATRIX_RES_READY_POOL,
        FSM_TRANSFER_MATRIX_RES_POOL,
        FSM_UPDATE_MATRIX_RES_INDEX_POOL
    } state_fsm_t;

endpackage // dp_package
