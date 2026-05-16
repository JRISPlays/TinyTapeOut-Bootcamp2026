`default_nettype none

// Hardware period divisors translated from Arduino pitches.h
`define NOTE_FS3 8'd90
`define NOTE_GS3 8'd80
`define NOTE_AS3 8'd76
`define NOTE_B3  8'd72
`define NOTE_CS4 8'd64
`define NOTE_D4  8'd60
`define NOTE_DS4 8'd57
`define NOTE_FS4 8'd48
`define NOTE_GS4 8'd43
`define NOTE_DS5 8'd28
`define NOTE_E5  8'd27
`define NOTE_FS5 8'd24
`define NOTE_B5  8'd18
`define NOTE_AS5 8'd19
`define NOTE_DS6 8'd14
`define NOTE_E6  8'd13
`define NOTE_REST 8'd0

module tt_um_vga_example(
  input  wire [7:0] ui_in,    // Dedicated inputs
  output wire [7:0] uo_out,   // Dedicated outputs
  input  wire [7:0] uio_in,   // IOs: Input path
  output wire [7:0] uio_out,  // IOs: Output path
  output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
  input  wire       ena,      // always 1 when the design is powered
  input  wire       clk,      // clock
  input  wire       rst_n     // reset_n - low to reset
);

  // VGA signals
  wire hsync;
  wire vsync;
  wire [1:0] R;
  wire [1:0] G;
  wire [1:0] B;
  wire video_active;
  wire [9:0] x; 
  wire [9:0] y; 
  wire sound;

  // Video output assignment
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

  // Connect the audio engine signal to the playground's virtual speaker pin
  assign uio_out = {sound, 7'b0};
  assign uio_oe  = 8'hff;

  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(x),
    .vpos(y)
  );

  // --- ANIMATION & MELODY STEP TRACKER ---
  reg [8:0] frame_count; 
  reg laugh_state;
  
  always @(posedge vsync or negedge rst_n) begin
    if (~rst_n) begin
      frame_count <= 0;
      laugh_state <= 0;
    end else begin
      frame_count <= frame_count + 1;
      // Mouth animations sync directly to the signature 16th-note Nyan speed
      laugh_state <= frame_count[3]; 
    end
  end

  // --- FPGA HARDWARE AUDIO PARSER ---
  reg [7:0] note_freq;
  reg [7:0] note_counter;
  reg       note_wave;
  
  // Extracts the note positions sequentially every 8 frames to match the fast 130BPM tempo
  wire [3:0] track_step = frame_count[6:3];

  // Map the signature Nyan Cat Melody sequence using a synthesis-friendly lookup table
  always @(*) begin
    case(track_step)
      4'd0  : note_freq = `NOTE_DS5;
      4'd1  : note_freq = `NOTE_E5;
      4'd2  : note_freq = `NOTE_FS5;
      4'd3  : note_freq = `NOTE_REST;
      4'd4  : note_freq = `NOTE_B5;
      4'd5  : note_freq = `NOTE_E5;
      4'd6  : note_freq = `NOTE_DS5;
      4'd7  : note_freq = `NOTE_E5;
      4'd8  : note_freq = `NOTE_FS5;
      4'd9  : note_freq = `NOTE_B5;
      4'd10 : note_freq = `NOTE_DS6;
      4'd11 : note_freq = `NOTE_E6;
      4'd12 : note_freq = `NOTE_DS6;
      4'd13 : note_freq = `NOTE_AS5;
      4'd14 : note_freq = `NOTE_B5;
      4'd15 : note_freq = `NOTE_REST;
      default: note_freq = `NOTE_REST;
    endcase
  end

  // Generate square wave tone locked to the horizontal blanking edge (x == 0)
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      note_counter <= 0;
      note_wave    <= 0;
    end else begin
      if (x == 0) begin
        if (note_freq == `NOTE_REST) begin
          note_counter <= 0;
          note_wave    <= 0;
        end else if (note_counter >= note_freq) begin
          note_counter <= 0;
          note_wave    <= ~note_wave;
        end else begin
          note_counter <= note_counter + 1'b1;
        end
      end
    end
  end

  // Send the waveform straight to the mixer during valid display windows
  assign sound = note_wave & video_active;


  // --- SPONGEBOB GEOMETRY DEFINITIONS ---
  wire [9:0] bounce = laugh_state ? 6 : 0;
  wire [9:0] adj_y = y + bounce;

  wire is_body       = (x >= 270 && x <= 370 && adj_y >= 160 && adj_y <= 270);
  
  wire is_hole       = (x >= 280 && x <= 290 && adj_y >= 170 && adj_y <= 180) ||
                       (x >= 350 && x <= 360 && adj_y >= 185 && adj_y <= 195) ||
                       (x >= 345 && x <= 355 && adj_y >= 245 && adj_y <= 255) ||
                       (x >= 285 && x <= 292 && adj_y >= 240 && adj_y <= 250);

  wire is_shirt      = (x >= 270 && x <= 370 && adj_y >= 271 && adj_y <= 282);
  wire is_pants      = (x >= 270 && x <= 370 && adj_y >= 283 && adj_y <= 305);
  wire is_tie        = (x >= 316 && x <= 324 && adj_y >= 275 && adj_y <= 295);

  wire is_eye_white_l = (x >= 285 && x <= 315 && adj_y >= 185 && adj_y <= 215);
  wire is_eye_white_r = (x >= 325 && x <= 355 && adj_y >= 185 && adj_y <= 215);
  
  wire is_iris_l      = (x >= 297 && x <= 311 && adj_y >= 193 && adj_y <= 207);
  wire is_iris_r      = (x >= 329 && x <= 343 && adj_y >= 193 && adj_y <= 207);
  
  wire is_pupil_l     = (x >= 301 && x <= 307 && adj_y >= 197 && adj_y <= 203);
  wire is_pupil_r     = (x >= 333 && x <= 339 && adj_y >= 197 && adj_y <= 203);

  wire is_mouth_open  = laugh_state && (x >= 295 && x <= 345 && adj_y >= 225 && adj_y <= 255);
  wire is_mouth_close = !laugh_state && (x >= 305 && x <= 335 && adj_y >= 233 && adj_y <= 242);
  wire is_mouth       = is_mouth_open || is_mouth_close;

  wire is_teeth       = laugh_state && (
                        (x >= 308 && x <= 316 && adj_y >= 225 && adj_y <= 235) || 
                        (x >= 324 && x <= 332 && adj_y >= 225 && adj_y <= 235)
                       );


  // --- COLOR GENERATION PIPELINE ---
  reg [5:0] rgb_out;
  
  always @(*) begin
    if (!video_active) begin
      rgb_out = 6'b000000;
    end else if (is_teeth) begin
      rgb_out = 6'b111111;
    end else if (is_pupil_l || is_pupil_r) begin
      rgb_out = 6'b000000;
    end else if (is_iris_l || is_iris_r) begin
      rgb_out = 6'b000111;
    end else if (is_eye_white_l || is_eye_white_r) begin
      rgb_out = 6'b111111;
    end else if (is_mouth) begin
      rgb_out = 6'b100000;
    end else if (is_tie) begin
      rgb_out = 6'b110000;
    end else if (is_pants) begin
      rgb_out = 6'b100100;
    end else if (is_shirt) begin
      rgb_out = 6'b111111;
    end else if (is_hole) begin
      rgb_out = 6'b101100;
    end else if (is_body) begin
      rgb_out = 6'b111100;
    end else begin
      rgb_out = 6'b001011;
    end
  end

  assign {R, G, B} = rgb_out;

  // Suppress unused signals warning
  wire _unused_ok = &{ena, ui_in, uio_in};
endmodule