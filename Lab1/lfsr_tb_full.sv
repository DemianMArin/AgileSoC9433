module lfsr_tb_full();

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

  // ---------------------------------------------------------------
  // load takes precedence over enable when both are asserted
  // ---------------------------------------------------------------
  load  = 1;
  seed  = 7'b1010101;
  @(posedge clk);
  #1;
  load = 0;

  load   = 1;
  enable = 1;
  seed   = 7'b0001111;
  @(posedge clk);
  #1;
  if (lfsr_out !== seed) begin       // load wins over enable -> seed value, not a shift
    $display("@@@FAIL");
    $finish;
  end
  load   = 0;
  enable = 0;

  // ---------------------------------------------------------------
  // hold: no control signals asserted -> state must not change
  // ---------------------------------------------------------------
  @(posedge clk);
  #1;
  if (lfsr_out !== 7'b0001111) begin
    $display("@@@FAIL");
    $finish;
  end
  @(posedge clk);
  #1;
  if (lfsr_out !== 7'b0001111) begin
    $display("@@@FAIL");
    $finish;
  end

  // ---------------------------------------------------------------
  // shift/taps: single enable step from a known seed
  // ---------------------------------------------------------------
  load = 1;
  seed = 7'b1100111;
  @(posedge clk);
  #1;
  load = 0;

  enable = 1;
  @(posedge clk);
  #1;
  if (lfsr_out !== 7'b1001110) begin // D6^D5 fed into D0, left shift
    $display("@@@FAIL");
    $finish;
  end
  enable = 0;

  // ---------------------------------------------------------------
  // full sequence/period: 127 shifts from the seed return to the seed
  // ---------------------------------------------------------------
  load = 1;
  seed = 7'b1100111;
  @(posedge clk);
  #1;
  load = 0;

  enable = 1;
  for (int i = 0; i < 127; i++) begin
    @(posedge clk);
    #1;
    if (lfsr_out === 7'b1100111 && i != 126) begin // seed must not repeat early
      $display("@@@FAIL");
      $finish;
    end
  end
  enable = 0;

  if (lfsr_out !== 7'b1100111) begin // cycle 127 -> back to seed
    $display("@@@FAIL");
    $finish;
  end

  $display("@@@PASS");
  $finish;
end: testbench

initial begin: monitor
  $monitor("%t RESET:%b LOAD:%b ENABLE:%b SEED:%b LFSR_OUT:%b", $realtime, reset, load, enable, seed, lfsr_out);
end: monitor

endmodule: lfsr_tb_full
