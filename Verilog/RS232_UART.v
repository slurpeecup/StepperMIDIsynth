module UART_RX
#(parameter f_sysclk  = 40_000_000,  // default for iCE40-UP5K
            baudrate  = 31250,       // default baudrate for MIDI std 
            ndatabit  = 8,           // default for midi std
            nstopbit  = 1,           // default for midi std (can be 1 , 2)
            npbit     = 0,           // default for midi std  (can be 0 , 1)
            pty_lvl   = 0,           // even parity by default, else odd parity
            endian    = 0,           // parallel bits order (default little endian)
            activelo  = 1            // default active low
 )
( input sysclk, 
  input s_in, 
  output reg [ndatabit - 1: 0] p_out,
  output d_valid
);

localparam CKSperCYC = f_sysclk / baudrate; ///baudrate count of cyc/sec

reg [ndatabit + npbit - 1 : 0] dataframe = 0; // for now no need to store startbit 

localparam IDLE = 0;
localparam BUSY = 1;
localparam DONE = 2;
localparam RST  = 3;

reg STATE = 0;

localparam HALF = 1;
localparam WHOLE = 0;

reg clkdiv;



reg enGen_start;
reg enGen_en;
reg enGen_rst;

EN_Generator #(.TIME_TO_EN(CKSperCYC)) EN0 (.sysclk(sysclk), .strt(enGen_start), .rst(enGen_rst), .rsh(clkdiv), .EN(enGen_en));

reg [$clog2(1 + ndatabit + nstopbit + npbit) - 1 : 0] frame_iterator = 0;
reg [$clog2((1 + ndatabit + nstopbit + npbit) / 2) - 1 : 0] zero_ctr = 0;
reg [$clog2((1 + ndatabit + nstopbit + npbit) / 2) - 1 : 0] ones_ctr = 0;

always @ (posedge sysclk)
  begin
    case (STATE)
      IDLE            : begin
      clkdiv = HALF;
        if (s_in == 0)
          begin
            readstart = 1;
            if (enGen_en) // on the clock pulse where s_in is still low AND a half cycle has passed.
              begin
                enGen_rst      <= 1'b1;
                clkdiv         <= WHOLE;
                frame_iterator <= 0;
                dataframe      <= 0;
                zero_ctr       <= 0;
                ones_ctr       <= 0;
                STATE          <= BUSY;
              end
            /* @ first s_in, kicks off the read. 
               if s_in is still 0 after 1, it is fine that readstart still = 1; this value will not be stored.
               but then we want to wait for one cycle after that half cycle.
            */
          end
                        end

      BUSY            : begin
      enGen_rst <= 0;
      frame_iterator <= frame_iterator + 1;
        
        if (frame_iterator >= (ndatabit + npbit))
          begin
            if (npbit > 0)  // if parity checking
              begin
                d_valid <= 1;
                endianness == 0? p_out == dataframe [0 +: ndatabit] 
                               : p_out == dataframe [ndatabit + npbit - 1 -: ndatabit];
                STATE   <= IDLE;
              end
        
          end
        else
          begin
            endian == 0? dataframe[i] <= s_in : dataframe [ndatabit - 1 - i] <= s_in;
            if (npbit > 0)
              s_in   == 0? zero_ctr <= zero_ctr + 1 : ones_ctr <= ones_ctr + 1;
          end
                        end
    endcase 

  end




endmodule

module EN_Generator                  // clk dividers no good . selfref: https://electronics.stackexchange.com/questions/222972/advantage-of-clock-enable-over-clock-division
# (parameter TIME_TO_EN = 10_000_000)
(input sysclk, input strt, input rst, input [3:0] rsh, output EN);

reg STATE;
reg en;

localparam IDLE = 0;
localparam CT   = 1;

unsigned reg [$clog2(TIME_TO_EN) - 1 : 0] internal_ctr;

always @ (posedge sysclk)
  begin
  
  case (STATE)
    IDLE          :  begin

    internal_ctr <= 0;
    en           <= 0;
      if (rst) 
        begin
          internal_ctr <= 0;
        end
      if (strt) 
        begin
          STATE <= CT;
        end
      else 
        begin
          STATE <= IDLE;
        end
                     end

    CT            :  begin
      
      if (internal_ctr >= (TIME_TO_EN >> rsh)) // divide the clk within enable gen // this can be space-optimized w/ a barrel shifter
        begin
          en <= 1;
          STATE = IDLE;
        end
      if (internal_ctr < TIME_TO_EN)
        begin
          internal_ctr = internal_ctr + 1;
        end             
                     end

  endcase
  end
assign EN = en;
endmodule