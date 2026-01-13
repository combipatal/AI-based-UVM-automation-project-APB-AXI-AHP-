module simple_ram #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter RAM_DEPTH  = 256
)(
    input  wire                  clk,
    input  wire                  en,
    input  wire                  we,
    input  wire [ADDR_WIDTH-1:0] addr,
    input  wire [DATA_WIDTH-1:0] wdata,
    output wire [DATA_WIDTH-1:0] rdata // Combinatorial read to match simple Verilog array behavior
);

    // Memory Array
    reg [DATA_WIDTH-1:0] mem [0:RAM_DEPTH-1];

    // Write: Synchronous
    always @(posedge clk) begin
        if (en && we) begin
            mem[addr] <= wdata;
        end
    end

    // Read: Asynchronous (Combinatorial)
    // This matches "rdata <= mem[addr]" inside a clocked block in the parent
    assign rdata = (en) ? mem[addr] : {DATA_WIDTH{1'b0}};

endmodule
