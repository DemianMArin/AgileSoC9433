module spi_tb (
  output logic sclk,
  output logic cs_n,
  output logic mosi,
  input  logic miso
);

  localparam int FRAME_BITS = 44;

  logic [1:0]  op    = 2'b11;          // write
  logic [9:0]  addr  = {2'b00, 8'h2B}; // addr = 43
  logic [31:0] data  = 32'hDEADBEEF;
  //logic [31:0] data  = 32'h00000005;


  logic [FRAME_BITS-1:0] tx_frame;
  logic [FRAME_BITS-1:0] echo;

  int i;

  initial begin: clk_gen
    sclk = 0;
    forever #5 sclk = ~sclk;
  end: clk_gen

  initial begin
    cs_n     = 1;
    mosi     = 0;
    tx_frame = {op, addr, data};

    // wait for a clean start, then assert cs_n synchronously with bit 0
    @(negedge sclk);
    cs_n = 0;
    mosi = tx_frame[FRAME_BITS-1]; // bit 43 (MSB) first

    for (i = 1; i < FRAME_BITS; i++) begin
      @(negedge sclk);
      mosi = tx_frame[FRAME_BITS-1-i];
    end

    // 2-cycle latency: slave WAIT -> MEM before it starts driving miso
    @(negedge sclk); mosi = 0;
    @(negedge sclk); mosi = 0;
    @(posedge sclk); mosi = 0; //counter should start in posedge after w_en is enabled and after first bit is sent
    
    // response phase: sample miso, MSB first
    for (i = 0; i < FRAME_BITS; i++) begin
      @(posedge sclk); //missing 2 bits
      echo[FRAME_BITS-1-i] = miso;
    end
    
    @(negedge sclk);
    cs_n = 1;
    mosi = 0;

    if (echo !== tx_frame)
      $display("FAIL: sent %h, echoed %h", tx_frame, echo);
      $display("@@@FAIL");
    else
      $display("PASS: write echoed back %h", echo);

    $display("@@@PASS");
    #20 $finish;
  end

endmodule
