module spi_tb (
  output logic sclk,
  output logic cs_n,
  output logic mosi,
  input  logic miso
);

  localparam int FRAME_BITS = 44;

  logic [FRAME_BITS-1:0] echo_wr;
  logic [FRAME_BITS-1:0] echo_rd;

  initial begin: clk_gen
    sclk = 0;
    forever #5 sclk = ~sclk;
  end: clk_gen

  task automatic do_txn(
    input  logic [1:0]  op,
    input  logic [9:0]  addr,
    input  logic [31:0] data,
    output logic [FRAME_BITS-1:0] echo
  );
    logic [FRAME_BITS-1:0] tx_frame;
    int i;

    tx_frame = {op, addr, data};

    // assert cs_n synchronously with bit 0
    @(negedge sclk);
    cs_n = 0;
    mosi = tx_frame[FRAME_BITS-1]; // MSB first

    for (i = 1; i < FRAME_BITS; i++) begin
      @(negedge sclk);
      mosi = tx_frame[FRAME_BITS-1-i];
    end

    // 2-cycle latency: slave WAIT -> MEM before it starts driving miso
    @(negedge sclk); mosi = 0;
    @(negedge sclk); mosi = 0;

    // skip the MEM->TX load posedge; land sampling on the first real driven bit
    @(posedge sclk);

    // response phase: sample miso, MSB first
    for (i = 0; i < FRAME_BITS; i++) begin
      @(posedge sclk);
      echo[FRAME_BITS-1-i] = miso;
    end

    @(negedge sclk);
    cs_n = 1;
    mosi = 0;
  endtask

  initial begin
    cs_n = 1;
    mosi = 0;

    // write DEADBEE1 to addr 43
    do_txn(2'b11, {2'b00, 8'h2B}, 32'hDEADBEE1, echo_wr);
    if (echo_wr !== {2'b11, 10'({2'b00, 8'h2B}), 32'hDEADBEE1}) begin
      $display("FAIL write: echoed %h", echo_wr);
      $display("@@@FAIL");
    end else begin
      $display("PASS write: echoed %h", echo_wr);
    end

    // one idle cs_n=1 negedge between transactions
    @(negedge sclk);

    // read back addr 43, data field don't-care on the wire
    do_txn(2'b10, {2'b00, 8'h2B}, 32'hAAAAAAAA, echo_rd);
    if (echo_rd[31:0] !== 32'hDEADBEE1) begin
      $display("FAIL read: expected %h, got %h", 32'hDEADBEE1, echo_rd[31:0]);
      $display("@@@FAIL");
    end else begin
      $display("PASS read: echoed data %h matches write", echo_rd[31:0]);
    end

    $display("@@@PASS");
    #20 $finish;
  end

endmodule
