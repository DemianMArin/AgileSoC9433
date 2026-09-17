module spi_tb (
  output logic sclk,
  output logic cs_n,
  output logic mosi,
  input  logic miso
);

  localparam int FRAME_BITS = 44;

  int errors = 0;

  logic [FRAME_BITS-1:0] echo_wr;
  logic [FRAME_BITS-1:0] echo_rd;

  initial begin: clk_gen
    sclk = 0;
    forever #5 sclk = ~sclk;
  end: clk_gen

  task automatic check_miso_zero(string tag);
    if (miso !== 1'b0) begin
      $display("FAIL: miso != 0 during %s (miso=%b)", tag, miso);
      errors++;
    end
  endtask

  // op/addr/data go out MSB-first; if is_first, asserts cs_n and optionally
  // idles mosi=0 for lead_zeros cycles first (delay tolerance, spec 4.6);
  // if !is_first, starts the new frame on the very next negedge with cs_n
  // left untouched (back-to-back chaining, spec 4.7). Checks miso==0
  // throughout the message + WAIT/MEM phases (spec 3, 4.5). If is_last,
  // deasserts cs_n after the response.
  task automatic do_txn(
    input  logic [1:0]  op,
    input  logic [9:0]  addr,
    input  logic [31:0] data,
    output logic [FRAME_BITS-1:0] echo,
    input  int  lead_zeros,
    input  bit  is_first,
    input  bit  is_last
  );
    logic [FRAME_BITS-1:0] frame;
    int i;
    frame = {op, addr, data};

    if (is_first) begin
      @(negedge sclk);
      cs_n = 0;
      mosi = 0;
      for (i = 0; i < lead_zeros; i++) begin
        @(posedge sclk);
        check_miso_zero("pre-start delay");
        @(negedge sclk);
        mosi = 0;
      end
      mosi = frame[FRAME_BITS-1]; // start bit (MSB)
    end else begin
      @(negedge sclk);
      mosi = frame[FRAME_BITS-1]; // start bit, no cs_n change
    end

    @(posedge sclk);
    check_miso_zero("message phase");

    for (i = 1; i < FRAME_BITS; i++) begin
      @(negedge sclk);
      mosi = frame[FRAME_BITS-1-i];
      @(posedge sclk);
      check_miso_zero("message phase");
    end

    @(negedge sclk); mosi = 0;
    @(posedge sclk); check_miso_zero("wait state");
    @(negedge sclk); mosi = 0;
    @(posedge sclk); check_miso_zero("mem state");

    for (i = 0; i < FRAME_BITS; i++) begin
      @(posedge sclk);
      echo[FRAME_BITS-1-i] = miso;
    end

    if (is_last) begin
      @(negedge sclk);
      cs_n = 1;
      mosi = 0;
    end
  endtask

  initial begin
    cs_n = 1;
    mosi = 0;

    // idle: miso must read 0 while cs_n=1, before any transaction
    repeat (3) begin
      @(posedge sclk);
      check_miso_zero("idle cs_n=1");
    end

    // write with arbitrary delay before start bit (delay tolerance, spec 4.6)
    do_txn(2'b11, {2'b00, 8'h2B}, 32'hDEADBEE1, echo_wr, 5, 1'b1, 1'b0);
    if (echo_wr !== {2'b11, 10'({2'b00, 8'h2B}), 32'hDEADBEE1}) begin
      $display("FAIL write: echoed %h", echo_wr);
      errors++;
    end

    // back-to-back read, same cs_n session, no gap (spec 4.7)
    do_txn(2'b10, {2'b00, 8'h2B}, 32'hAAAAAAAA, echo_rd, 0, 1'b0, 1'b1);
    if (echo_rd !== {2'b10, 10'({2'b00, 8'h2B}), 32'hDEADBEE1}) begin
      $display("FAIL read: echoed %h", echo_rd);
      errors++;
    end

    // idle again: miso must be back to 0 after cs_n deasserted
    repeat (3) begin
      @(posedge sclk);
      check_miso_zero("idle cs_n=1 after txn");
    end

    if (errors != 0) begin
      $display("@@@FAIL");
    end else begin
      $display("@@@PASS");
    end

    #20 $finish;
  end

endmodule
