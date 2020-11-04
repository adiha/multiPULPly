import dp_package::*;
import hwpe_stream_package::*;

module dp_streamer
#(
    parameter int unsigned N_MASTER_PORT = 4 //,
    // parameter int unsigned FIFO_DEPTH = 2  // FIFO depth
)
(
    // global signals
    input  logic                   clk_i,
    input  logic                   rst_ni,
    input  logic                   test_mode_i,
    // local enable & clear
    input  logic                   enable_i,
    input  logic                   clear_i,

    // input mat stream + handshake
    hwpe_stream_intf_stream.source dp0_mat_o,
    hwpe_stream_intf_stream.source dp1_mat_o,
    // input vec stream + handshake
    hwpe_stream_intf_stream.source dp0_vec_o,
    hwpe_stream_intf_stream.source dp1_vec_o,
    // output res stream + handshake
    hwpe_stream_intf_stream.sink   dp0_res_i,
    hwpe_stream_intf_stream.sink   dp1_res_i,

    // TCDM ports
    hwpe_stream_intf_tcdm.master tcdm [N_MASTER_PORT-1:0],

    // control channel
    input  ctrl_streamer_t  dp0_ctrl_i,
    input  ctrl_streamer_t  dp1_ctrl_i,
    output flags_streamer_t dp0_flags_o,
    output flags_streamer_t dp1_flags_o
);

    hwpe_stream_intf_tcdm dp0_mat_streamer2mux [1] (
        .clk(clk_i)
    );

    hwpe_stream_intf_tcdm dp0_vec_streamer2mux [1] (
        .clk(clk_i)
    );

    hwpe_stream_intf_tcdm dp1_mat_streamer2mux [1] (
        .clk(clk_i)
    );

    hwpe_stream_intf_tcdm dp1_vec_streamer2mux [1] (
        .clk(clk_i)
    );

    // hwpe_stream_intf_stream #(
        // .DATA_WIDTH ( 32 )
    // ) dp0_mat_stream_intf (
        // .clk ( clk_i )
    // );
    // hwpe_stream_intf_stream #(
        // .DATA_WIDTH ( 32 )
    // ) dp0_vec_stream_intf (
        // .clk ( clk_i )
    // );
    // hwpe_stream_intf_stream #(
        // .DATA_WIDTH ( 32 )
    // ) dp0_res_stream_intf (
        // .clk ( clk_i )
    // );

    // hwpe_stream_intf_stream #(
        // .DATA_WIDTH ( 32 )
    // ) dp1_mat_stream_intf (
        // .clk ( clk_i )
    // );
    // hwpe_stream_intf_stream #(
        // .DATA_WIDTH ( 32 )
    // ) dp1_vec_stream_intf (
        // .clk ( clk_i )
    // );
    // hwpe_stream_intf_stream #(
        // .DATA_WIDTH ( 32 )
    // ) dp1_res_stream_intf (
        // .clk ( clk_i )
    // );

    hwpe_stream_tcdm_mux_static #(
        .NB_CHAN(1)
    ) dp0_mat_vec_mux (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .clear_i(clear_i),
        .sel_i(dp0_ctrl_i.mat_vec_stream_sel),
        .in0(dp0_mat_streamer2mux.slave),
        .in1(dp0_vec_streamer2mux.slave),
        .out(tcdm[0:0])
    );

    hwpe_stream_tcdm_mux_static #(
        .NB_CHAN(1)
    ) dp1_mat_vec_mux (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .clear_i(clear_i),
        .sel_i(dp1_ctrl_i.mat_vec_stream_sel),
        .in0(dp1_mat_streamer2mux.slave),
        .in1(dp1_vec_streamer2mux.slave),
        .out(tcdm[2:2])
    );

    hwpe_stream_source #(
        .DATA_WIDTH ( 32 )
    ) i_dp0_mat_source (
        .clk_i              ( clk_i                        ),
        .rst_ni             ( rst_ni                       ),
        .test_mode_i        ( test_mode_i                  ),
        .clear_i            ( clear_i                      ),
        .tcdm               ( dp0_mat_streamer2mux.master  ), // this syntax is necessary as hwpe_stream_source expects an array of interfaces
        .stream             ( dp0_mat_o                    ),
        .ctrl_i             ( dp0_ctrl_i.mat_source_ctrl   ),
        .flags_o            ( dp0_flags_o.mat_source_flags )
    );

    hwpe_stream_source #(
        .DATA_WIDTH ( 32 )
    ) i_dp0_vec_source (
        .clk_i              ( clk_i                        ),
        .rst_ni             ( rst_ni                       ),
        .test_mode_i        ( test_mode_i                  ),
        .clear_i            ( clear_i                      ),
        .tcdm               ( dp0_vec_streamer2mux.master  ), // this syntax is necessary as hwpe_stream_source expects an array of interfaces
        .stream             ( dp0_vec_o                    ),
        .ctrl_i             ( dp0_ctrl_i.vec_source_ctrl   ),
        .flags_o            ( dp0_flags_o.vec_source_flags )
    );

    hwpe_stream_sink #(
        .DATA_WIDTH ( 32 )
    ) i_dp0_res_sink (
        .clk_i       ( clk_i                      ),
        .rst_ni      ( rst_ni                     ),
        .test_mode_i ( test_mode_i                ),
        .clear_i     ( clear_i                    ),
        .tcdm        ( tcdm[1:1]                  ), // this syntax is necessary as hwpe_stream_source expects an array of interfaces
        .stream      ( dp0_res_i                  ),
        .ctrl_i      ( dp0_ctrl_i.res_sink_ctrl   ),
        .flags_o     ( dp0_flags_o.res_sink_flags )
    );

    hwpe_stream_source #(
        .DATA_WIDTH ( 32 )
    ) i_dp1_mat_source (
        .clk_i              ( clk_i                        ),
        .rst_ni             ( rst_ni                       ),
        .test_mode_i        ( test_mode_i                  ),
        .clear_i            ( clear_i                      ),
        .tcdm               ( dp1_mat_streamer2mux.master  ), // this syntax is necessary as hwpe_stream_source expects an array of interfaces
        .stream             ( dp1_mat_o                    ),
        .ctrl_i             ( dp1_ctrl_i.mat_source_ctrl   ),
        .flags_o            ( dp1_flags_o.mat_source_flags )
    );

    hwpe_stream_source #(
        .DATA_WIDTH ( 32 )
    ) i_dp1_vec_source (
        .clk_i              ( clk_i                        ),
        .rst_ni             ( rst_ni                       ),
        .test_mode_i        ( test_mode_i                  ),
        .clear_i            ( clear_i                      ),
        .tcdm               ( dp1_vec_streamer2mux.master  ), // this syntax is necessary as hwpe_stream_source expects an array of interfaces
        .stream             ( dp1_vec_o                    ),
        .ctrl_i             ( dp1_ctrl_i.vec_source_ctrl   ),
        .flags_o            ( dp1_flags_o.vec_source_flags )
    );

    hwpe_stream_sink #(
        .DATA_WIDTH ( 32 )
    ) i_dp1_res_sink (
        .clk_i       ( clk_i                      ),
        .rst_ni      ( rst_ni                     ),
        .test_mode_i ( test_mode_i                ),
        .clear_i     ( clear_i                    ),
        .tcdm        ( tcdm[3:3]                  ), // this syntax is necessary as hwpe_stream_source expects an array of interfaces
        .stream      ( dp1_res_i                  ),
        .ctrl_i      ( dp1_ctrl_i.res_sink_ctrl   ),
        .flags_o     ( dp1_flags_o.res_sink_flags )
    );

    // hwpe_stream_fifo #(
        // .DATA_WIDTH( 32         ),
        // .FIFO_DEPTH( FIFO_DEPTH ),
        // .LATCH_FIFO( 0          )
    // ) i_dp0_mat_fifo (
        // .clk_i   ( clk_i                    ),
        // .rst_ni  ( rst_ni                   ),
        // .clear_i ( clear_i                  ),
        // .push_i  ( dp0_mat_stream_intf.sink ),
        // .pop_o   ( dp0_mat_o                ),
        // .flags_o (                          )
    // );

    // hwpe_stream_fifo #(
        // .DATA_WIDTH( 32         ),
        // .FIFO_DEPTH( FIFO_DEPTH ),
        // .LATCH_FIFO( 0          )
    // ) i_dp0_vec_fifo (
        // .clk_i   ( clk_i                    ),
        // .rst_ni  ( rst_ni                   ),
        // .clear_i ( clear_i                  ),
        // .push_i  ( dp0_vec_stream_intf.sink ),
        // .pop_o   ( dp0_vec_o                ),
        // .flags_o (                          )
    // );

    // hwpe_stream_fifo #(
        // .DATA_WIDTH( 32         ),
        // .FIFO_DEPTH( FIFO_DEPTH ),
        // .LATCH_FIFO( 0          )
    // ) i_dp0_res_fifo (
        // .clk_i   ( clk_i                      ),
        // .rst_ni  ( rst_ni                     ),
        // .clear_i ( clear_i                    ),
        // .push_i  ( dp0_res_i                  ),
        // .pop_o   ( dp0_res_stream_intf.source ),
        // .flags_o (                            )
    // );

    // hwpe_stream_fifo #(
        // .DATA_WIDTH( 32         ),
        // .FIFO_DEPTH( FIFO_DEPTH ),
        // .LATCH_FIFO( 0          )
    // ) i_dp1_mat_fifo (
        // .clk_i   ( clk_i                    ),
        // .rst_ni  ( rst_ni                   ),
        // .clear_i ( clear_i                  ),
        // .push_i  ( dp1_mat_stream_intf.sink ),
        // .pop_o   ( dp1_mat_o                ),
        // .flags_o (                          )
    // );

    // hwpe_stream_fifo #(
        // .DATA_WIDTH( 32         ),
        // .FIFO_DEPTH( FIFO_DEPTH ),
        // .LATCH_FIFO( 0          )
    // ) i_dp1_vec_fifo (
        // .clk_i   ( clk_i                    ),
        // .rst_ni  ( rst_ni                   ),
        // .clear_i ( clear_i                  ),
        // .push_i  ( dp1_vec_stream_intf.sink ),
        // .pop_o   ( dp1_vec_o                ),
        // .flags_o (                          )
    // );

    // hwpe_stream_fifo #(
        // .DATA_WIDTH( 32         ),
        // .FIFO_DEPTH( FIFO_DEPTH ),
        // .LATCH_FIFO( 0          )
    // ) i_dp1_res_fifo (
        // .clk_i   ( clk_i                      ),
        // .rst_ni  ( rst_ni                     ),
        // .clear_i ( clear_i                    ),
        // .push_i  ( dp1_res_i                  ),
        // .pop_o   ( dp1_res_stream_intf.source ),
        // .flags_o (                            )
    // );

endmodule // dp_streamer
