import dp_package::*;
import hwpe_ctrl_package::*;

module dp_ctrl
#(
    parameter int unsigned N_CORES         = 1,
    parameter int unsigned N_CONTEXT       = 2,
    parameter int unsigned N_IO_REGS       = DP_REG_NUM_REGS,
    parameter int unsigned ID              = 10
)
(
    // global signals
    input  logic                                  clk_i,
    input  logic                                  rst_ni,
    input  logic                                  test_mode_i,
    output logic                                  clear_o,
    // events
    output logic [N_CORES-1:0][REGFILE_N_EVT-1:0] evt_o,
    // discretes
    output logic                                  add_enable_o,
    // ctrl & flags
    output ctrl_streamer_t                        dp0_ctrl_streamer_o,
    output ctrl_streamer_t                        dp1_ctrl_streamer_o,
    input  flags_streamer_t                       dp0_flags_streamer_i,
    input  flags_streamer_t                       dp1_flags_streamer_i,
    output ctrl_engine_t                          dp0_ctrl_engine_o,
    output ctrl_engine_t                          dp1_ctrl_engine_o,
    input  flags_engine_t                         dp0_flags_engine_i,
    input  flags_engine_t                         dp1_flags_engine_i,
    // periph slave port
    hwpe_ctrl_intf_periph.slave                   periph
);

    ctrl_slave_t   slave_ctrl;
    flags_slave_t  slave_flags;
    ctrl_slave_t   dp0_slave_ctrl;
    flags_slave_t  dp0_slave_flags;
    ctrl_slave_t   dp1_slave_ctrl;
    flags_slave_t  dp1_slave_flags;
    ctrl_regfile_t reg_file;

    logic unsigned [31:0] static_reg_dp_enable;
    logic unsigned [31:0] static_reg_dp0_mat_height;
    logic unsigned [31:0] static_reg_dp0_num_of_vectors;
    logic unsigned [31:0] static_reg_dp0_mat_width;
    logic unsigned [31:0] static_reg_dp0_sub_mat_height;
    logic unsigned [31:0] static_reg_dp0_sub_mat_width;
    logic unsigned [31:0] static_reg_dp0_sub_mat_base_addr;
    logic unsigned [31:0] static_reg_dp0_sub_vec_base_addr;
    logic unsigned [31:0] static_reg_dp0_res_base_addr;
    logic unsigned [31:0] static_reg_dp0_mat_transfer_enable;
    logic unsigned [31:0] static_reg_dp0_res_to_buffer;
    logic unsigned [31:0] static_reg_dp0_res_transfer_enable;
    logic unsigned [31:0] static_reg_dp1_mat_height;
    logic unsigned [31:0] static_reg_dp1_num_of_vectors;
    logic unsigned [31:0] static_reg_dp1_mat_width;
    logic unsigned [31:0] static_reg_dp1_sub_mat_height;
    logic unsigned [31:0] static_reg_dp1_sub_mat_width;
    logic unsigned [31:0] static_reg_dp1_sub_mat_base_addr;
    logic unsigned [31:0] static_reg_dp1_sub_vec_base_addr;
    logic unsigned [31:0] static_reg_dp1_res_base_addr;
    logic unsigned [31:0] static_reg_dp1_mat_transfer_enable;
    logic unsigned [31:0] static_reg_dp1_res_to_buffer;
    logic unsigned [31:0] static_reg_dp1_res_transfer_enable;
    logic unsigned [31:0] static_reg_dp_add_enable;
    logic unsigned [31:0] static_reg_dp0_res_buffer_index;
    logic unsigned [31:0] static_reg_dp1_res_buffer_index;
    logic unsigned [31:0] static_reg_dp_pool_sel;
    logic unsigned [31:0] static_reg_dp_mat_width_div3;
    logic unsigned [31:0] static_reg_dp_stride;

    logic dp0_done_level;
    logic dp1_done_level;
    logic dp0_dp1_done;

    ucode_t            dp0_ucode;
    ctrl_ucode_t       dp0_ucode_ctrl;
    flags_ucode_t      dp0_ucode_flags;
    logic [11:0][31:0] dp0_ucode_registers_read;
    ucode_t            dp1_ucode;
    ctrl_ucode_t       dp1_ucode_ctrl;
    flags_ucode_t      dp1_ucode_flags;
    logic [11:0][31:0] dp1_ucode_registers_read;

    ctrl_fsm_t dp0_fsm_ctrl;
    ctrl_fsm_t dp1_fsm_ctrl;

    /* Peripheral slave & register file */
    hwpe_ctrl_slave #(
        .N_CORES        ( N_CORES               ),
        .N_CONTEXT      ( N_CONTEXT             ),
        .N_IO_REGS      ( N_IO_REGS             ),
        .N_GENERIC_REGS ( 0                     ),
        .ID_WIDTH       ( ID                    )
    ) i_slave (
        .clk_i    ( clk_i       ),
        .rst_ni   ( rst_ni      ),
        .clear_o  ( clear_o     ),
        .cfg      ( periph      ),
        .ctrl_i   ( slave_ctrl  ),
        .flags_o  ( slave_flags ),
        .reg_file ( reg_file    )
    );
    assign evt_o = slave_flags.evt;

    /* Direct register file mappings */
    assign static_reg_dp_enable                  = reg_file.hwpe_params[DP_REG_DP_ENABLE                 ];
    assign static_reg_dp0_mat_height             = reg_file.hwpe_params[DP_REG_DP0_MAT_HEIGHT            ];
    assign static_reg_dp0_num_of_vectors         = reg_file.hwpe_params[DP_REG_DP0_NUM_OF_VECTORS        ];
    assign static_reg_dp0_mat_width              = reg_file.hwpe_params[DP_REG_DP0_MAT_WIDTH             ];
    assign static_reg_dp0_sub_mat_height         = reg_file.hwpe_params[DP_REG_DP0_SUB_MAT_HEIGHT        ];
    assign static_reg_dp0_sub_mat_width          = reg_file.hwpe_params[DP_REG_DP0_SUB_MAT_WIDTH         ];
    assign static_reg_dp0_sub_mat_base_addr      = reg_file.hwpe_params[DP_REG_DP0_SUB_MAT_BASE_ADDR     ];
    assign static_reg_dp0_sub_vec_base_addr      = reg_file.hwpe_params[DP_REG_DP0_SUB_VEC_BASE_ADDR     ];
    assign static_reg_dp0_res_base_addr          = reg_file.hwpe_params[DP_REG_DP0_RES_BASE_ADDR         ];
    assign static_reg_dp0_mat_transfer_enable    = reg_file.hwpe_params[DP_REG_DP0_MAT_TRANSFER_ENABLE   ];
    assign static_reg_dp0_res_to_buffer          = reg_file.hwpe_params[DP_REG_DP0_RES_TO_BUFFER         ];
    assign static_reg_dp0_res_transfer_enable    = reg_file.hwpe_params[DP_REG_DP0_RES_TRANSFER_ENABLE   ];
    assign static_reg_dp1_mat_height             = reg_file.hwpe_params[DP_REG_DP1_MAT_HEIGHT            ];
    assign static_reg_dp1_num_of_vectors         = reg_file.hwpe_params[DP_REG_DP1_NUM_OF_VECTORS        ];
    assign static_reg_dp1_mat_width              = reg_file.hwpe_params[DP_REG_DP1_MAT_WIDTH             ];
    assign static_reg_dp1_sub_mat_height         = reg_file.hwpe_params[DP_REG_DP1_SUB_MAT_HEIGHT        ];
    assign static_reg_dp1_sub_mat_width          = reg_file.hwpe_params[DP_REG_DP1_SUB_MAT_WIDTH         ];
    assign static_reg_dp1_sub_mat_base_addr      = reg_file.hwpe_params[DP_REG_DP1_SUB_MAT_BASE_ADDR     ];
    assign static_reg_dp1_sub_vec_base_addr      = reg_file.hwpe_params[DP_REG_DP1_SUB_VEC_BASE_ADDR     ];
    assign static_reg_dp1_res_base_addr          = reg_file.hwpe_params[DP_REG_DP1_RES_BASE_ADDR         ];
    assign static_reg_dp1_mat_transfer_enable    = reg_file.hwpe_params[DP_REG_DP1_MAT_TRANSFER_ENABLE   ];
    assign static_reg_dp1_res_to_buffer          = reg_file.hwpe_params[DP_REG_DP1_RES_TO_BUFFER         ];
    assign static_reg_dp1_res_transfer_enable    = reg_file.hwpe_params[DP_REG_DP1_RES_TRANSFER_ENABLE   ];
    assign static_reg_dp_add_enable              = reg_file.hwpe_params[DP_REG_ADD_ENABLE                ];
    assign static_reg_dp0_res_buffer_index       = reg_file.hwpe_params[DP_REG_DP0_RES_BUFFER_INDEX      ];
    assign static_reg_dp1_res_buffer_index       = reg_file.hwpe_params[DP_REG_DP1_RES_BUFFER_INDEX      ];
    assign static_reg_dp_pool_sel                = reg_file.hwpe_params[DP_REG_DP_POOL_SEL               ];
    assign static_reg_dp_mat_width_div3          = reg_file.hwpe_params[DP_REG_SUB_MAT_WIDTH_DIV3        ];
    assign static_reg_dp_stride                  = reg_file.hwpe_params[DP_REG_DP_STRIDE                 ];
    
    assign dp0_ucode_registers_read[DP_UCODE_MNEM_MAT_HEIGHT]     = static_reg_dp0_mat_height;
    assign dp0_ucode_registers_read[DP_UCODE_MNEM_NUM_OF_VECTORS] = static_reg_dp0_num_of_vectors;
    assign dp0_ucode_registers_read[DP_UCODE_MNEM_MAT_WIDTH]      = static_reg_dp0_mat_width;
    assign dp0_ucode_registers_read[DP_UCODE_MNEM_SUB_MAT_HEIGHT] = static_reg_dp0_sub_mat_height;
    assign dp0_ucode_registers_read[11:DP_UCODE_NUM_RO_REGS] = '0;
    assign dp1_ucode_registers_read[DP_UCODE_MNEM_MAT_HEIGHT]     = static_reg_dp1_mat_height;
    assign dp1_ucode_registers_read[DP_UCODE_MNEM_NUM_OF_VECTORS] = static_reg_dp1_num_of_vectors;
    assign dp1_ucode_registers_read[DP_UCODE_MNEM_MAT_WIDTH]      = static_reg_dp1_mat_width;
    assign dp1_ucode_registers_read[DP_UCODE_MNEM_SUB_MAT_HEIGHT] = static_reg_dp1_sub_mat_height;
    assign dp1_ucode_registers_read[11:DP_UCODE_NUM_RO_REGS] = '0;

    hwpe_ctrl_ucode #(
        .NB_LOOPS  ( 1                     ),
        .NB_REG    ( DP_UCODE_NUM_RW_REGS  ),
        .NB_RO_REG ( DP_UCODE_NUM_RO_REGS  )
    ) i_ucode_dp0 (
        .clk_i            ( clk_i                    ),
        .rst_ni           ( rst_ni                   ),
        .test_mode_i      ( test_mode_i              ),
        .clear_i          ( clear_o                  ),
        .ctrl_i           ( dp0_ucode_ctrl           ),
        .flags_o          ( dp0_ucode_flags          ),
        .ucode_i          ( dp0_ucode                ),
        .registers_read_i ( dp0_ucode_registers_read )
    );

    hwpe_ctrl_ucode #(
        .NB_LOOPS  ( 1                     ),
        .NB_REG    ( DP_UCODE_NUM_RW_REGS  ),
        .NB_RO_REG ( DP_UCODE_NUM_RO_REGS  )
    ) i_ucode_dp1 (
        .clk_i            ( clk_i                    ),
        .rst_ni           ( rst_ni                   ),
        .test_mode_i      ( test_mode_i              ),
        .clear_i          ( clear_o                  ),
        .ctrl_i           ( dp1_ucode_ctrl           ),
        .flags_o          ( dp1_ucode_flags          ),
        .ucode_i          ( dp1_ucode                ),
        .registers_read_i ( dp1_ucode_registers_read )
    );

    /* Main FSM */
    dp_fsm i_fsm_dp0 (
        .clk_i                  ( clk_i                    ),
        .rst_ni                 ( rst_ni                   ),
        .test_mode_i            ( test_mode_i              ),
        .clear_i                ( clear_o                  ),
        .ctrl_streamer_o        ( dp0_ctrl_streamer_o      ),
        .flags_streamer_i       ( dp0_flags_streamer_i     ),
        .flags_other_streamer_i ( dp1_flags_streamer_i     ),
        .ctrl_engine_o          ( dp0_ctrl_engine_o        ),
        .flags_engine_i         ( dp0_flags_engine_i       ),
        .ctrl_ucode_o           ( dp0_ucode_ctrl           ),
        .flags_ucode_i          ( dp0_ucode_flags          ),
        .ctrl_slave_o           ( dp0_slave_ctrl           ),
        .flags_slave_i          ( dp0_slave_flags          ),
        .ctrl_i                 ( dp0_fsm_ctrl             ),
        .ucode_o                ( dp0_ucode                )
    );

    /* Main FSM */
    dp_fsm i_fsm_dp1 (
        .clk_i                  ( clk_i                    ),
        .rst_ni                 ( rst_ni                   ),
        .test_mode_i            ( test_mode_i              ),
        .clear_i                ( clear_o                  ),
        .ctrl_streamer_o        ( dp1_ctrl_streamer_o      ),
        .flags_streamer_i       ( dp1_flags_streamer_i     ),
        .flags_other_streamer_i ( dp0_flags_streamer_i     ),
        .ctrl_engine_o          ( dp1_ctrl_engine_o        ),
        .flags_engine_i         ( dp1_flags_engine_i       ),
        .ctrl_ucode_o           ( dp1_ucode_ctrl           ),
        .flags_ucode_i          ( dp1_ucode_flags          ),
        .ctrl_slave_o           ( dp1_slave_ctrl           ),
        .flags_slave_i          ( dp1_slave_flags          ),
        .ctrl_i                 ( dp1_fsm_ctrl             ),
        .ucode_o                ( dp1_ucode                )
    );

    always_comb
    begin
        dp0_fsm_ctrl.sub_mat_width            = static_reg_dp0_sub_mat_width;
        dp0_fsm_ctrl.sub_mat_height           = static_reg_dp0_sub_mat_height;
        dp0_fsm_ctrl.num_of_vectors           = static_reg_dp0_num_of_vectors;
        dp0_fsm_ctrl.sub_mat_base_addr        = static_reg_dp0_sub_mat_base_addr;
        dp0_fsm_ctrl.sub_vec_base_addr        = static_reg_dp0_sub_vec_base_addr;
        dp0_fsm_ctrl.res_base_addr            = static_reg_dp0_res_base_addr;
        dp0_fsm_ctrl.mat_transfer_enable      = static_reg_dp0_mat_transfer_enable[0];
        dp0_fsm_ctrl.res_to_buffer            = static_reg_dp0_res_to_buffer[0];
        dp0_fsm_ctrl.res_transfer_enable      = static_reg_dp0_res_transfer_enable[0];
        dp0_fsm_ctrl.res_streamer_enable      = ~static_reg_dp_add_enable[0];
        dp0_fsm_ctrl.res_buffer_index         = static_reg_dp0_res_buffer_index;
        dp0_fsm_ctrl.sub_mat_width_div3       = static_reg_dp_mat_width_div3;
        dp0_fsm_ctrl.dp_pool_sel              = static_reg_dp_pool_sel;
        dp0_fsm_ctrl.stride                   = static_reg_dp_stride;
        dp1_fsm_ctrl.sub_mat_width            = static_reg_dp1_sub_mat_width;
        dp1_fsm_ctrl.sub_mat_height           = static_reg_dp1_sub_mat_height;
        dp1_fsm_ctrl.num_of_vectors           = static_reg_dp1_num_of_vectors;
        dp1_fsm_ctrl.sub_mat_base_addr        = static_reg_dp1_sub_mat_base_addr;
        dp1_fsm_ctrl.sub_vec_base_addr        = static_reg_dp1_sub_vec_base_addr;
        dp1_fsm_ctrl.res_base_addr            = static_reg_dp1_res_base_addr;
        dp1_fsm_ctrl.mat_transfer_enable      = static_reg_dp1_mat_transfer_enable[0];
        dp1_fsm_ctrl.res_to_buffer            = static_reg_dp1_res_to_buffer[0];
        dp1_fsm_ctrl.res_transfer_enable      = static_reg_dp1_res_transfer_enable[0];
        dp1_fsm_ctrl.res_streamer_enable      = 1'b1;
        dp1_fsm_ctrl.res_buffer_index         = static_reg_dp1_res_buffer_index;
        dp1_fsm_ctrl.sub_mat_width_div3       = static_reg_dp_mat_width_div3;
        dp1_fsm_ctrl.dp_pool_sel              = static_reg_dp_pool_sel;
        dp1_fsm_ctrl.stride                   = static_reg_dp_stride;
    end

    always_ff @(posedge clk_i or negedge rst_ni)
    begin
        if (~rst_ni) begin
            dp0_done_level <= 1'b0;
            dp1_done_level <= 1'b0;
            dp0_dp1_done <= 1'b0;
        end
        else begin
            // Defaulting to create a pulse.
            dp0_dp1_done <= 1'b0;

            // Convert pulse of dp0 done to level.
            if (dp0_slave_ctrl.done) begin
                dp0_done_level <= 1'b1;
            end
            // Convert pulse of dp1 done to level.
            if (dp1_slave_ctrl.done) begin
                dp1_done_level <= 1'b1;
            end

            // If all active levels are high, generate a pulse and de-assert levels.
            if ((dp0_done_level | !static_reg_dp_enable[0]) & (dp1_done_level | !static_reg_dp_enable[1])) begin
                dp0_dp1_done <= 1'b1;
                dp0_done_level <= 1'b0;
                dp1_done_level <= 1'b0;
            end

            // If all levels are inactive (could happen between jobs), just de-assert all done signals.
            if (!static_reg_dp_enable[0] & !static_reg_dp_enable[1]) begin
                dp0_dp1_done <= 1'b0;
                dp0_done_level <= 1'b0;
                dp1_done_level <= 1'b0;
            end
        end
    end

    assign slave_ctrl.done = dp0_dp1_done;
    assign slave_ctrl.evt  = 0;

    always_comb
    begin
        dp0_slave_flags.start      = slave_flags.start & static_reg_dp_enable[0];
        dp1_slave_flags.start      = slave_flags.start & static_reg_dp_enable[1];
        dp0_slave_flags.evt        = slave_flags.evt;
        dp1_slave_flags.evt        = slave_flags.evt;
        dp0_slave_flags.done       = slave_flags.done;
        dp1_slave_flags.done       = slave_flags.done;
        dp0_slave_flags.is_working = slave_flags.is_working;
        dp1_slave_flags.is_working = slave_flags.is_working;
        dp0_slave_flags.enable     = slave_flags.enable;
        dp1_slave_flags.enable     = slave_flags.enable;
    end

    assign add_enable_o = static_reg_dp_add_enable[0];

endmodule
