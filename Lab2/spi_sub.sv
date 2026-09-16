module spi_sub (
  // SPI signals
  input logic sclk,
  input logic cs_n,
  input logic mosi,
  output logic miso,
  // Memory signals
  output logic r_en,
  output logic w_en,
  output logic [9:0] addr,
  output logic [31:0] data_o,
  input logic [31:0] data_i
);

  localparam int FRAME_BITS = 44; // 2 (op) + 10 (addr) + 32 (data)

  typedef enum logic [2:0] {IDLE, RX, WAIT, MEM, TX} state_t;
  state_t state;

  logic [FRAME_BITS-1:0] rx_shift;
  logic [FRAME_BITS-1:0] tx_shift;
  logic [FRAME_BITS-1:0] resp_data;
  logic [5:0]            bit_cnt;

  wire [1:0]  op_r    = rx_shift[43:42];
  wire [9:0]  addr_r  = rx_shift[41:32];
  wire [31:0] wdata_r = rx_shift[31:0];

  // ---------------- capture phase: sample mosi on posedge ----------------
  always_ff @(posedge sclk) begin
    if (cs_n) begin
      state   <= IDLE;
      bit_cnt <= '0;
    end else begin
      unique case (state)
        IDLE: begin
          if (mosi) begin
            // start bit seen; frame begins here (tolerate arbitrary delay of 0s before this)
            rx_shift <= {rx_shift[FRAME_BITS-2:0], mosi};
            bit_cnt  <= 1;
            state    <= RX;
          end
          // else: stay in IDLE, discard the 0 bit
        end
        RX: begin
          rx_shift <= {rx_shift[FRAME_BITS-2:0], mosi};
          bit_cnt  <= bit_cnt + 1;
          if (bit_cnt == FRAME_BITS-1) state <= WAIT; // last bit just captured
        end
        WAIT: begin
          state <= MEM; // next posedge: w_en/r_en go high
        end
        MEM: begin
          // r_en/w_en (below) held high this whole state, one full cycle;
          // data_i is valid this same cycle for reads
          resp_data <= (op_r == 2'b11) ? rx_shift : {op_r, addr_r, data_i}; // 11 write, 10 read
          bit_cnt   <= 0;
          state     <= TX;
        end
        TX: begin
          bit_cnt <= bit_cnt + 1;
          if (bit_cnt == FRAME_BITS-1) state <= IDLE;
        end
        default: state <= IDLE;
      endcase
    end
  end

  assign r_en   = (state == MEM) && (op_r == 2'b10);
  assign w_en   = (state == MEM) && (op_r == 2'b11);
  assign addr   = addr_r;
  assign data_o = wdata_r;

  // ---------------- drive phase: shift response out on negedge ----------------
  always_ff @(negedge sclk) begin
    if (cs_n) begin
      miso     <= 1'b0;
      tx_shift <= '0;
    end else if (state == TX) begin
      if (bit_cnt == 0) begin
        // first TX bit: load from resp_data (latched this same cycle by MEM->TX posedge)
        miso     <= resp_data[FRAME_BITS-1];
        tx_shift <= {resp_data[FRAME_BITS-2:0], 1'b0};
      end else begin
        miso     <= tx_shift[FRAME_BITS-1];
        tx_shift <= {tx_shift[FRAME_BITS-2:0], 1'b0};
      end
    end else begin
      miso <= 1'b0;
    end
  end

endmodule
