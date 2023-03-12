`timescale 1ns/10ps
module IOTDF( clk, rst, in_en, iot_in, fn_sel, busy, valid, iot_out);
  input          clk;
  input          rst;
  input          in_en;
  input  [7:0]   iot_in;
  input  [2:0]   fn_sel;
  output reg         busy;
  output reg         valid;
  output reg [127:0] iot_out;

  //================================
  //  PARAMETERS
  //================================
  integer i;
  
  parameter INPUT_DATA_WIDTH = 8;
  parameter WORD             = 128;
  parameter PERIOD = 16;
  parameter ROUND_COUNT = 8;
  localparam EXU_LOW =  128'h7fff_ffff_ffff_ffff_ffff_ffff_ffff_ffff;
  localparam EXU_HIGH = 128'hbfff_ffff_ffff_ffff_ffff_ffff_ffff_ffff;
  localparam EXT_LOW  = 128'h6fff_ffff_ffff_ffff_ffff_ffff_ffff_ffff;
  localparam EXT_HIGH  = 128'hafff_ffff_ffff_ffff_ffff_ffff_ffff_ffff;

  localparam  MAX = 1;
  localparam  MIN = 2;
  localparam  AVG = 3;
  localparam  EXTRACT = 4;
  localparam  EXCLUDE= 5;
  localparam  PEAK_MAX= 6;
  localparam  PEAK_MIN= 7;

  reg[3:0] pipe_down_cnt;
  reg[3:0] round_cnt;
  reg[3:0] total_time_cnt;
  reg[INPUT_DATA_WIDTH-1:0] iot_in_bufs[0:15];
  reg[WORD+3:0] alu_buf1;
  reg[WORD+3:0] peak_ff;
  reg[WORD+3:0] result_ff;
  reg state_bit;

  //================================================================
  //  MAIN DESIGN
  //================================================================
  //================================
  //  state indicators
  //================================
  wire   state_MAX      = fn_sel == 1;
  wire   state_MIN      = fn_sel == 2;
  wire   state_AVG      = fn_sel == 3;
  wire   state_EXTRACT  = fn_sel == 4;
  wire   state_EXCLUDE  = fn_sel == 5;
  wire   state_PEAK_MAX = fn_sel == 6;
  wire   state_PEAK_MIN = fn_sel == 7;

  //================================
  //  CONTROL FLAGS
  //================================
  wire round_ends_f  = round_cnt == 0;
  wire round_decre_f = pipe_down_cnt == 0;
  reg round_decre_d_f,round_decre_d2_f,round_decre_d3_f;
  reg round_ends_d_f,round_ends_d2_f;
  reg extract_d_f,extract_d2_f, exclude_d_f,exclude_d2_f;

  wire extract_f = (alu_buf1 > EXT_LOW && alu_buf1 < EXT_HIGH);
  wire exclude_f = (alu_buf1 < EXU_LOW || alu_buf1 > EXU_HIGH);
  wire peak_lt_f = (result_ff < peak_ff);
  wire peak_st_f = (result_ff >= peak_ff);

  always @(posedge clk or posedge rst)
  begin
    if (rst) begin
      round_decre_d_f <= 0;
      round_decre_d2_f <= 0;
      round_ends_d_f <= 0;
      round_ends_d2_f <= 0;
      round_decre_d3_f <= 0;
      extract_d_f    <= 0;
      //extract_d2_f   <= 0;
      exclude_d_f    <= 0;
      //exclude_d2_f   <= 0;
    end
    else begin
      round_decre_d_f <= round_decre_f;
      round_decre_d2_f <= round_decre_d_f;
      round_ends_d_f <= round_ends_f;
      round_ends_d2_f <= round_ends_d_f;
      round_decre_d3_f <= round_decre_d2_f;
      extract_d_f    <= extract_f;
      //extract_d2_f   <= extract_d_f;
      exclude_d_f    <= exclude_f;
      //exclude_d2_f   <= exclude_d_f;
    end
  end

  always @(posedge clk or posedge rst) begin 
      if(rst) begin
         state_bit <= 0;
      end 
      else if(in_en) begin
         state_bit <= 1;
      end
  end


  //================================
  //  CNT
  //================================
  always @(posedge clk or posedge rst)
  begin: DOWN_CNT
    if(rst)
    begin
      pipe_down_cnt <= 15;
    end
    else if(in_en)
    begin
      pipe_down_cnt <= pipe_down_cnt - 1;
    end
    else
    begin
      pipe_down_cnt <= pipe_down_cnt;
    end
  end

  always @(posedge clk or posedge rst)
  begin: ROUND_CNT
    if(rst)
    begin
      round_cnt <= 8;
    end
    else if(round_cnt == 0) begin
      round_cnt <= 8;
    end
    else if(round_decre_f)
    begin
      round_cnt <= round_cnt - 1;
    end
    else
    begin
      round_cnt <= round_cnt;
    end
  end

  always @(posedge clk or posedge rst) begin 
    if(rst) begin
      total_time_cnt <= 0;
    end 
    else if(valid) begin
      total_time_cnt <= total_time_cnt + 1;
    end
  end

  //================================
  //  BUFFERS
  //================================
  always @(posedge clk or posedge rst)
  begin
    if (rst)
    begin
      for ( i= 0; i<16; i=i+1)
      begin
        iot_in_bufs[i] <= 'd0;
      end
    end
    else if(in_en)
    begin
      iot_in_bufs[0] <= iot_in;
      for ( i= 0; i<15; i=i+1)
      begin
        iot_in_bufs[i+1] <= iot_in_bufs[i];
      end
    end
    else
    begin
      for ( i= 0; i<16; i=i+1)
      begin
        iot_in_bufs[i] <= iot_in_bufs[i];
      end
    end
  end

  //================================
  //  ALU
  //================================

  always @(posedge clk or posedge rst)
  begin
    if (rst)
    begin
      alu_buf1 <= 'd0;
    end
    else if(round_decre_d_f)
    begin
      for ( i= 0; i<16; i=i+1)
      begin
        alu_buf1[INPUT_DATA_WIDTH*i +: INPUT_DATA_WIDTH] <= iot_in_bufs[i];
      end
    end
    else
    begin
      alu_buf1 <= alu_buf1;
    end
  end


  always @(posedge clk or posedge rst)
  begin
    if (rst)
    begin
      result_ff <= 'd0;
    end
    else if(round_decre_d2_f)
    begin
      case(fn_sel)
        MAX:
        begin
          result_ff <= (alu_buf1 > result_ff) ? alu_buf1 : result_ff;
        end
        MIN:
        begin
          result_ff <= (alu_buf1 <= result_ff) ? alu_buf1 : result_ff;
        end
        AVG:
        begin
          result_ff <= result_ff + alu_buf1;
        end
        EXTRACT:
        begin
          result_ff <= extract_f ? alu_buf1 : 0;
        end
        EXCLUDE:
        begin
          result_ff <= exclude_f ? alu_buf1 : 0;
        end
        PEAK_MAX:
        begin
          result_ff <= (alu_buf1 > result_ff) ? alu_buf1 : result_ff;
        end
        PEAK_MIN:
        begin
          result_ff <= (alu_buf1 <= result_ff) ? alu_buf1 : result_ff;
        end
        default:
        begin
          result_ff <= 3;
        end
      endcase
    end
    else if(valid || !state_bit) begin
      case(fn_sel)
        MAX:
        begin
          result_ff <= 0;
        end
        MIN:
        begin
          result_ff <= 0-1;
        end
        AVG:
        begin
          result_ff <= 0;
        end
        EXTRACT:
        begin
          result_ff <= 0;
        end
        EXCLUDE:
        begin
          result_ff <= 0;
        end
        PEAK_MAX:
        begin
          result_ff <= 0;
        end
        PEAK_MIN:
        begin
          result_ff <= 0-1;
        end
        default:
        begin
          result_ff <= 0;
        end
      endcase
    end
    else
    begin
      result_ff <= result_ff;
    end
  end

  always @(posedge clk or posedge rst)
  begin
    if (rst)
    begin
      peak_ff <= 0;
    end
    else if(!state_bit & state_PEAK_MIN) begin
      peak_ff <= 0 -1 ;
    end
    else if(valid)
    begin
      if(state_PEAK_MAX) peak_ff <= peak_st_f ? result_ff : peak_ff;
      else if(state_PEAK_MIN) peak_ff <= peak_lt_f ? result_ff : peak_ff;
    end
    else
    begin
      peak_ff <= peak_ff;
    end
  end

  //================================
  //  I/O
  //================================
  always @(posedge clk or posedge rst)
  begin
    if(rst)
    begin
      valid <= 0;
    end
    else
    begin
      case(fn_sel)
        MAX,AVG,MIN:
        begin
          valid <= round_ends_d2_f ? 1 : 0;
        end
        EXTRACT:
        begin
          valid <= round_decre_d3_f & extract_d_f ? 1 : 0;
        end
        EXCLUDE:
        begin
          valid <= round_decre_d3_f & exclude_d_f ? 1 : 0;
        end
        PEAK_MIN:
        begin
          valid <= round_ends_d2_f & peak_lt_f ? 1 : 0;
        end
        PEAK_MAX:
        begin
          valid <= round_ends_d2_f & peak_st_f ? 1 : 0;
        end
        default:
        begin
          valid <=  0;
        end
      endcase
    end
  end

  always @(*) begin 
    busy = round_decre_f;
  end

  always @(posedge clk or posedge rst)
  begin
    if(rst)
    begin
      iot_out <= 0;
    end
    else
    begin
      case(fn_sel)
        PEAK_MIN,PEAK_MAX,MAX,MIN:
        begin
          iot_out <= round_ends_d2_f ? result_ff[127:0] : 0;
        end
        AVG:
        begin
          iot_out <= round_ends_d2_f ? result_ff[130:3] : 0;
        end
        EXCLUDE,EXTRACT:
        begin
          iot_out <= round_decre_d3_f ? result_ff[127:0] : 0;
        end
        default:
        begin
          iot_out <= 0;
        end
      endcase
    end
  end


endmodule
