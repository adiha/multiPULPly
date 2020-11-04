module dot_product_bit
#(
    parameter RRAM_DOTP_HEIGHT = 512,
    parameter RRAM_DOTP_WIDTH  = 512,
    parameter WORD_SIZE        = 16,
    parameter WORD_SIZE_MATRIX = 8
)(
    input logic unsigned [0:RRAM_DOTP_HEIGHT - 1] vector_bits,
    input logic unsigned [0:RRAM_DOTP_HEIGHT-1][0:RRAM_DOTP_WIDTH-1][WORD_SIZE_MATRIX - 1:0] matrix,
    output logic unsigned [0:RRAM_DOTP_WIDTH-1][WORD_SIZE - 1:0] result
);

    always_comb
    begin
        integer i;
        integer j;
        for (i = 0; i < RRAM_DOTP_WIDTH; i++) begin
            result[i] = 0;
        end
        for (i = 0; i < RRAM_DOTP_WIDTH; i++) begin
            for (j = 0; j < RRAM_DOTP_HEIGHT; j++) begin
                result[i] += vector_bits[j] * matrix[j][i];
            end
        end
    end

endmodule
