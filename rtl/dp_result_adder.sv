import dp_package::*;
import hwpe_stream_package::*;

module dp_result_adder
(
    
    // global signals
    input  logic                     clk_i,
    input  logic                     rst_ni,
    input  logic                     test_mode_i,
    
    input  logic                     add_enable_i,
    
    hwpe_stream_intf_stream.sink     dp0_i,
    hwpe_stream_intf_stream.sink     dp1_i,
    hwpe_stream_intf_stream.source   adder0_o,
    hwpe_stream_intf_stream.source   adder1_o
    
);

    always_ff @(posedge clk_i or negedge rst_ni)
    begin : adder0_data_proc
        if (~rst_ni) begin
            adder0_o.data <= 0;
            adder0_o.strb <= 4'b0;
        end
        else begin
            if (add_enable_i) begin
                adder0_o.data <= 0;
                adder0_o.strb <= 4'b0;
            end
            else begin
                if (dp0_i.valid && dp0_i.ready) begin
                    if (!adder0_o.valid) begin
                        adder0_o.data <= dp0_i.data;
                        adder0_o.strb <= dp0_i.strb;
                    end
                    else begin
                        if (adder0_o.ready) begin
                            adder0_o.data <= dp0_i.data;
                            adder0_o.strb <= dp0_i.strb;
                        end
                    end
                end
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni)
    begin : adder0_valid_proc
        if (~rst_ni) begin
            adder0_o.valid <= 1'b0;
        end
        else begin
            if (add_enable_i) begin
                adder0_o.valid <= 1'b0;
            end
            else begin
                if (dp0_i.valid && dp0_i.ready) begin
                    adder0_o.valid <= 1'b1;
                end
                else begin
                    if (adder0_o.ready) begin
                        adder0_o.valid <= 1'b0;
                    end
                end
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni)
    begin : dp0_ready_proc
        if (~rst_ni) begin
            dp0_i.ready <= 1'b0;
        end
        else begin
            dp0_i.ready <= 1'b0;

            if (add_enable_i) begin
                if (dp0_i.valid && dp1_i.valid) begin
                    if (!adder1_o.valid) begin
                        dp0_i.ready <= 1'b1;
                    end
                    else begin
                        if (adder1_o.ready) begin
                            dp0_i.ready <= 1'b1;
                        end
                    end
                end
            end
            else begin
                if (dp0_i.valid) begin
                    if (!adder0_o.valid) begin
                        dp0_i.ready <= 1'b1;
                    end
                    else begin
                        if (adder0_o.ready) begin
                            dp0_i.ready <= 1'b1;
                        end
                    end
                end
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni)
    begin : adder1_data_proc
        integer i;
        
        if (~rst_ni) begin
            adder1_o.data <= 0;
            adder1_o.strb <= 4'b0;
        end
        else begin
            if (add_enable_i) begin
                if (dp0_i.valid && dp1_i.valid && dp0_i.ready && dp1_i.ready) begin
                    if (!adder1_o.valid) begin
                        for (i = 0; i < adder1_o.DATA_WIDTH / WORD_SIZE; i++) begin
                            adder1_o.data[WORD_SIZE*i +: WORD_SIZE] <= dp0_i.data[WORD_SIZE*i +: WORD_SIZE] + dp1_i.data[WORD_SIZE*i +: WORD_SIZE];
                        end
                        adder1_o.strb <= 4'b1111;
                    end
                    else begin
                        if (adder1_o.ready) begin
                            for (i = 0; i < adder1_o.DATA_WIDTH / WORD_SIZE; i++) begin
                                adder1_o.data[WORD_SIZE*i +: WORD_SIZE] <= dp0_i.data[WORD_SIZE*i +: WORD_SIZE] + dp1_i.data[WORD_SIZE*i +: WORD_SIZE];
                            end
                            adder1_o.strb <= 4'b1111;
                        end
                    end
                end
            end
            else begin
                if (dp1_i.valid && dp1_i.ready) begin
                    if (!adder1_o.valid) begin
                        adder1_o.data <= dp1_i.data;
                        adder1_o.strb <= dp1_i.strb;
                    end
                    else begin
                        if (adder1_o.ready) begin
                            adder1_o.data <= dp1_i.data;
                            adder1_o.strb <= dp1_i.strb;
                        end
                    end
                end
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni)
    begin : adder1_valid_proc
        if (~rst_ni) begin
            adder1_o.valid <= 1'b0;
        end
        else begin
            if (add_enable_i) begin
                if (dp0_i.valid && dp1_i.valid && dp0_i.ready && dp1_i.ready) begin
                    adder1_o.valid <= 1'b1;
                end
                else begin
                    if (adder1_o.ready) begin
                        adder1_o.valid <= 1'b0;
                    end
                end
            end
            else begin
                if (dp1_i.valid && dp1_i.ready) begin
                    adder1_o.valid <= 1'b1;
                end
                else begin
                    if (adder1_o.ready) begin
                        adder1_o.valid <= 1'b0;
                    end
                end
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni)
    begin : dp1_ready_proc
        if (~rst_ni) begin
            dp1_i.ready <= 1'b0;
        end
        else begin
            dp1_i.ready <= 1'b0;

            if (add_enable_i) begin
                if (dp0_i.valid && dp1_i.valid) begin
                    if (!adder1_o.valid) begin
                        dp1_i.ready <= 1'b1;
                    end
                    else begin
                        if (adder1_o.ready) begin
                            dp1_i.ready <= 1'b1;
                        end
                    end
                end
            end
            else begin
                if (dp1_i.valid) begin
                    if (!adder1_o.valid) begin
                        dp1_i.ready <= 1'b1;
                    end
                    else begin
                        if (adder1_o.ready) begin
                            dp1_i.ready <= 1'b1;
                        end
                    end
                end
            end
        end
    end

endmodule
