module lfsr_tb_reset();

logic clk;
logic reset;
logic load;
logic enable;
logic [6:0] seed;
logic [6:0] lfsr_out;

lfsr DUT(.*);

initial begin: clk_gen
  clk = 0;
  forever #5 clk = ~clk;
end: clk_gen

// initial begin: fsdb_dump
//   $fsdbDumpfile("dump.fsdb");
//   $fsdbDumpvars;
// end: fsdb_dump

initial begin: testbench
  reset  = 0;
  load   = 0;
  enable = 0;
  seed   = 7'b0000000;

  // move DUT away from the reset value first, so the reset check is meaningful
  load = 1;
  seed = 7'b0101010;
  @(posedge clk);
  #1;
  load = 0;

  // apply synchronous reset
  reset = 1;
  @(posedge clk);
  #1;
  if (lfsr_out !== 7'b1111111) begin
    $display("@@@FAIL");
    $finish;
  end

  // reset held high should keep the state at all 1s
  @(posedge clk);
  #1;
  if (lfsr_out !== 7'b1111111) begin
    $display("@@@FAIL");
    $finish;
  end
  reset = 0;

  $display("@@@PASS");
  $finish;
end: testbench

initial begin: monitor
  $monitor("%t RESET:%b LOAD:%b ENABLE:%b SEED:%b LFSR_OUT:%b", $realtime, reset, load, enable, seed, lfsr_out);
end: monitor

endmodule: lfsr_tb_reset
