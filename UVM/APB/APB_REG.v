module APB_REG #(
    parameter REG_NUM_BITS = 4
) (
    input  wire        CLK,
    input  wire        RESETn,
    input  wire        i_psel,
    input  wire        i_penable,
    input  wire        i_pwrite,
    input  wire [31:0] i_paddr,
    input  wire [31:0] i_pwdata,
    output wire [31:0] o_prdata,
    output wire        o_pready,
    output wire        o_pslverr
);
    assign o_pready = 1'b1;
    assign o_pslverr = 1'b0;

    reg [31:0] regfile [2**REG_NUM_BITS-1:0];

    wire                    w_reg_rd_en;
    wire                    w_reg_wr_en;
    wire [REG_NUM_BITS-1:0] w_offset;

    assign w_reg_rd_en = i_psel & i_penable & ~i_pwrite;
    assign w_reg_wr_en = i_psel & i_penable &  i_pwrite;
    // APB uses byte addresses, convert to word index (addr >> 2)
    assign w_offset    = i_paddr[REG_NUM_BITS+1:2];

    // [Read Operation] - Combinational using assign
    assign o_prdata = (w_reg_rd_en) ? regfile[w_offset] : 32'd0;

    // [Write Operation] - Registered (on clock edge)
    always @(posedge CLK or negedge RESETn) begin
        if (!RESETn) begin
            // Optional: reset regfile if needed
        end else if (w_reg_wr_en) begin
            regfile[w_offset] <= i_pwdata;
        end
    end

endmodule