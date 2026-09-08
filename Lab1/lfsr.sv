module lfsr (
  input logic clk,
  input logic reset, // active-high synchronous reset
  input logic load, // load seed into LFSR
  input logic enable, // enable LFSR shift
  input logic [6:0] seed, // 7-bit seed value
  output logic [6:0] lfsr_out // current LFSR state
);

  logic [6:0] state;
  logic feedback;

  assign feedback = state[6] ^ state[5];
  assign lfsr_out = state;

  always_ff @(posedge clk) begin
    if (reset)
      state <= 7'b1111111;
    else if (load)
      state <= seed;
    else if (enable)
      state <= {state[5:0], feedback};
  end

endmodule
