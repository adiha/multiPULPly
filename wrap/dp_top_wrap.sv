import dp_package::*;
import hwpe_ctrl_package::*;
import hwpe_stream_package::*;

module dp_top_wrap
#(
    parameter N_MASTER_PORT = 4,
    parameter N_CORES = 1,
    parameter ID  = 10
)
(
    // global signals
    input  logic                                  clk_i,
    input  logic                                  rst_ni,
    input  logic                                  test_mode_i,
    // evnets
    output logic [N_CORES-1:0][REGFILE_N_EVT-1:0] evt_o,
    // tcdm master ports
    output logic [N_MASTER_PORT-1:0]              tcdm_req,
    input  logic [N_MASTER_PORT-1:0]              tcdm_gnt,
    output logic [N_MASTER_PORT-1:0][31:0]        tcdm_add,
    output logic [N_MASTER_PORT-1:0]              tcdm_wen,
    output logic [N_MASTER_PORT-1:0][3:0]         tcdm_be,
    output logic [N_MASTER_PORT-1:0][31:0]        tcdm_data,
    input  logic [N_MASTER_PORT-1:0][31:0]        tcdm_r_data,
    input  logic [N_MASTER_PORT-1:0]              tcdm_r_valid,
    // periph slave port
    input  logic                                  periph_req,
    output logic                                  periph_gnt,
    input  logic         [31:0]                   periph_add,
    input  logic                                  periph_wen,
    input  logic         [3:0]                    periph_be,
    input  logic         [31:0]                   periph_data,
    input  logic       [ID-1:0]                   periph_id,
    output logic         [31:0]                   periph_r_data,
    output logic                                  periph_r_valid,
    output logic       [ID-1:0]                   periph_r_id
);

    hwpe_stream_intf_tcdm tcdm[N_MASTER_PORT-1:0] (
        .clk ( clk_i )
    );

    hwpe_ctrl_intf_periph #(
        .ID_WIDTH ( ID )
    ) periph (
        .clk ( clk_i )
    );

    // bindings
    generate
        for (genvar ii=0; ii<N_MASTER_PORT; ii++) begin: tcdm_binding
            assign tcdm_req  [ii] = tcdm[ii].req;
            assign tcdm_add  [ii] = tcdm[ii].add;
            assign tcdm_wen  [ii] = tcdm[ii].wen;
            assign tcdm_be   [ii] = tcdm[ii].be;
            assign tcdm_data [ii] = tcdm[ii].data;
            assign tcdm[ii].gnt     = tcdm_gnt     [ii];
            assign tcdm[ii].r_data  = tcdm_r_data  [ii];
            assign tcdm[ii].r_valid = tcdm_r_valid [ii];
        end
    endgenerate

    always_comb
    begin
        periph.req  = periph_req;
        periph.add  = periph_add;
        periph.wen  = periph_wen;
        periph.be   = periph_be;
        periph.data = periph_data;
        periph.id   = periph_id;
        periph_gnt     = periph.gnt;
        periph_r_data  = periph.r_data;
        periph_r_valid = periph.r_valid;
        periph_r_id    = periph.r_id;
    end

    dp_top #(
        .N_MASTER_PORT ( N_MASTER_PORT ),
        .N_CORES       ( N_CORES       ),
        .ID            ( ID            )
    ) i_dp_top (
        .clk_i       ( clk_i        ),
        .rst_ni      ( rst_ni       ),
        .test_mode_i ( test_mode_i  ),
        .evt_o       ( evt_o        ),
        .tcdm        ( tcdm.master  ),
        .periph      ( periph.slave )
    );

endmodule // dp_top_wrap
