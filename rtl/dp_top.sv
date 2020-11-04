import dp_package::*;
import hwpe_ctrl_package::*;

module dp_top
#(
    parameter int unsigned N_MASTER_PORT = 4,
    parameter int unsigned N_CORES = 1,
    parameter int unsigned ID  = 10
)
(
    // global signals
    input  logic                                  clk_i,
    input  logic                                  rst_ni,
    input  logic                                  test_mode_i,
    // events
    output logic [N_CORES-1:0][REGFILE_N_EVT-1:0] evt_o,
    // tcdm master ports
    hwpe_stream_intf_tcdm.master                  tcdm[N_MASTER_PORT-1:0],
    // periph slave port
    hwpe_ctrl_intf_periph.slave                   periph
);

    logic add_enable;
    
    ctrl_streamer_t  dp0_streamer_ctrl;
    ctrl_streamer_t  dp1_streamer_ctrl;
    flags_streamer_t dp0_streamer_flags;
    flags_streamer_t dp1_streamer_flags;
    ctrl_engine_t    dp0_engine_ctrl;
    ctrl_engine_t    dp1_engine_ctrl;
    flags_engine_t   dp0_engine_flags;
    flags_engine_t   dp1_engine_flags;
    
    hwpe_stream_intf_stream #(
        .DATA_WIDTH(32)
    ) dp0_mat (
        .clk ( clk_i )
    );
    hwpe_stream_intf_stream #(
        .DATA_WIDTH(32)
    ) dp0_vec (
        .clk ( clk_i )
    );
    hwpe_stream_intf_stream #(
        .DATA_WIDTH(32)
    ) dp0_res (
        .clk ( clk_i )
    );

    hwpe_stream_intf_stream #(
        .DATA_WIDTH(32)
    ) dp1_mat (
        .clk ( clk_i )
    );
    hwpe_stream_intf_stream #(
        .DATA_WIDTH(32)
    ) dp1_vec (
        .clk ( clk_i )
    );
    hwpe_stream_intf_stream #(
        .DATA_WIDTH(32)
    ) dp1_res (
        .clk ( clk_i )
    );
    
    hwpe_stream_intf_stream #(
        .DATA_WIDTH(32)
    ) adder0_res (
        .clk ( clk_i )
    );
    
    hwpe_stream_intf_stream #(
        .DATA_WIDTH(32)
    ) adder1_res (
        .clk ( clk_i )
    );
    
    dp_engine i_dp0_engine (
        .clk_i        ( clk_i            ),
        .rst_ni       ( rst_ni           ),
        .test_mode_i  ( test_mode_i      ),
        .mat_i        ( dp0_mat.sink     ),
        .vec_i        ( dp0_vec.sink     ),
        .res_o        ( dp0_res.source   ),
        .ctrl_i       ( dp0_engine_ctrl  ),
        .flags_o      ( dp0_engine_flags )
    );

    dp_engine i_dp1_engine (
        .clk_i        ( clk_i            ),
        .rst_ni       ( rst_ni           ),
        .test_mode_i  ( test_mode_i      ),
        .mat_i        ( dp1_mat.sink     ),
        .vec_i        ( dp1_vec.sink     ),
        .res_o        ( dp1_res.source   ),
        .ctrl_i       ( dp1_engine_ctrl  ),
        .flags_o      ( dp1_engine_flags )
    );

    dp_result_adder i_adder (
        .clk_i        ( clk_i             ),
        .rst_ni       ( rst_ni            ),
        .add_enable_i ( add_enable        ),
        .dp0_i        ( dp0_res.sink      ),
        .dp1_i        ( dp1_res.sink      ),
        .adder0_o     ( adder0_res.source ),
        .adder1_o     ( adder1_res.source )
    );
    
    dp_streamer #(
        .N_MASTER_PORT            ( N_MASTER_PORT          )
    ) i_streamer (
        .clk_i                    ( clk_i                  ),
        .rst_ni                   ( rst_ni                 ),
        .test_mode_i              ( test_mode_i            ),
        .enable_i                 ( enable                 ),
        .clear_i                  ( clear                  ),
        .dp0_mat_o                ( dp0_mat.source         ),
        .dp1_mat_o                ( dp1_mat.source         ),
        .dp0_vec_o                ( dp0_vec.source         ),
        .dp1_vec_o                ( dp1_vec.source         ),
        .dp0_res_i                ( adder0_res.sink        ),
        .dp1_res_i                ( adder1_res.sink        ),
        .tcdm                     ( tcdm                   ),
        .dp0_ctrl_i               ( dp0_streamer_ctrl      ),
        .dp1_ctrl_i               ( dp1_streamer_ctrl      ),
        .dp0_flags_o              ( dp0_streamer_flags     ),
        .dp1_flags_o              ( dp1_streamer_flags     )
    );

    dp_ctrl #(
        .N_CORES   ( N_CORES ),
        .N_CONTEXT ( 2  ),
        .ID ( ID )
    ) i_ctrl (
        .clk_i                        ( clk_i                  ),
        .rst_ni                       ( rst_ni                 ),
        .test_mode_i                  ( test_mode_i            ),
        .clear_o                      ( clear                  ),
        .evt_o                        ( evt_o                  ),
        .add_enable_o                 ( add_enable             ),
        .dp0_ctrl_streamer_o          ( dp0_streamer_ctrl      ),
        .dp1_ctrl_streamer_o          ( dp1_streamer_ctrl      ),
        .dp0_flags_streamer_i         ( dp0_streamer_flags     ),
        .dp1_flags_streamer_i         ( dp1_streamer_flags     ),
        .dp0_ctrl_engine_o            ( dp0_engine_ctrl        ),
        .dp1_ctrl_engine_o            ( dp1_engine_ctrl        ),
        .dp0_flags_engine_i           ( dp0_engine_flags       ),
        .dp1_flags_engine_i           ( dp1_engine_flags       ),
        .periph                       ( periph                 )
    );

    assign enable = 1'b1;

endmodule // dp_top
