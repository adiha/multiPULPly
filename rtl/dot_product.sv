module dot_product
#(
    parameter RRAM_DOTP_HEIGHT = 512,
    parameter RRAM_DOTP_WIDTH  = 512,
    parameter WORD_SIZE        = 16,
    parameter WORD_SIZE_MATRIX = 8
)(
    input logic clk,
    input logic start,
    input logic signed [0:RRAM_DOTP_HEIGHT - 1][WORD_SIZE - 1:0] vector,
    input logic unsigned [0:RRAM_DOTP_HEIGHT-1][0:RRAM_DOTP_WIDTH-1][WORD_SIZE_MATRIX - 1:0] matrix,
    output logic signed [0:RRAM_DOTP_WIDTH - 1][WORD_SIZE - 1:0] result,
    output logic idle
);

    logic unsigned [0:RRAM_DOTP_HEIGHT - 1] vector_bits;
    logic unsigned [0:RRAM_DOTP_WIDTH-1][WORD_SIZE - 1:0] bit_result;

    typedef enum bit[1:0] {Idle_st = 2'b00, LoadFirstBit_st = 2'b01, LoadAndRead_st = 2'b10, ReadLast_st = 2'b11} STATE;
    STATE CUR_STATE;
    STATE NEXT_STATE;

    logic unsigned [$clog2(WORD_SIZE)-1:0] counter;

    always_ff @(posedge clk) begin
        CUR_STATE <= NEXT_STATE;
    end

    always_comb begin
        if (CUR_STATE == Idle_st) begin
            if (start == 1) begin
                NEXT_STATE = LoadFirstBit_st;
            end
            else begin
                NEXT_STATE = Idle_st;
            end
        end
        else if (CUR_STATE == LoadFirstBit_st) begin
            NEXT_STATE = LoadAndRead_st;
        end
        else if (CUR_STATE == LoadAndRead_st) begin
            if (counter == WORD_SIZE - 1) begin
                NEXT_STATE = ReadLast_st;
            end
            else begin
                NEXT_STATE = LoadAndRead_st;
            end
        end
        else begin
            NEXT_STATE = Idle_st;
        end
    end

    always_ff @(posedge clk) begin
        if (CUR_STATE == Idle_st) begin
            counter <= 0;
        end
        else if ((CUR_STATE == LoadFirstBit_st) | (CUR_STATE == LoadAndRead_st)) begin
            counter <= counter + 1;
        end
    end

    always_ff @(posedge clk) begin
        integer i;
        if (start == 1) begin
            for (i = 0; i < RRAM_DOTP_WIDTH; i++) begin
                result[i] <= 0;
            end
        end
        if ((CUR_STATE == LoadAndRead_st) | (CUR_STATE == ReadLast_st)) begin
            for (i = 0; i < RRAM_DOTP_WIDTH; i++) begin
                if (counter == 1) begin
                    result[i] <= signed'(result[i] << 1) - signed'({1'b0, bit_result[i]});
                end
                else begin
                    result[i] <= signed'(result[i] << 1) + signed'({1'b0, bit_result[i]});
                end
            end
        end
        if ((CUR_STATE == LoadFirstBit_st) | (CUR_STATE == LoadAndRead_st)) begin
            for (i = 0; i < RRAM_DOTP_HEIGHT; i++) begin
                vector_bits[i] <= vector[i][WORD_SIZE - counter - 1];
            end
        end
    end

    always_ff @(posedge clk) begin
        if (NEXT_STATE == Idle_st) begin
            idle <= 1;
        end
        else begin
            idle <= 0;
        end
    end
    //assign bit_result = 0;
    //assign result = 0;
    dot_product_bit #(
        .RRAM_DOTP_HEIGHT(RRAM_DOTP_HEIGHT),
        .RRAM_DOTP_WIDTH(RRAM_DOTP_WIDTH),
        .WORD_SIZE(WORD_SIZE),
        .WORD_SIZE_MATRIX(WORD_SIZE_MATRIX)
    ) dot_product_bit_U1 (
        .vector_bits(vector_bits),
        .matrix(matrix),
        .result(bit_result)
    );

endmodule
