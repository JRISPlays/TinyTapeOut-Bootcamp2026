`default_nettype none

module SpongeBob(
  input  wire [7:0] ui_in,    
  output wire [7:0] uo_out,   
  input  wire [7:0] uio_in,   
  output wire [7:0] uio_out,  
  output wire [7:0] uio_oe,   
  input  wire       ena,      
  input  wire       clk,      
  input  wire       rst_n     
);

  // VGA signals
  wire hsync;
  wire vsync;
  wire [1:0] R;
  wire [1:0] G;
  wire [1:0] B;
  wire video_active;
  wire [9:0] pix_x;
  wire [9:0] pix_y;

  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
  assign uio_out = 0;
  assign uio_oe  = 0;

  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(pix_x),
    .vpos(pix_y)
  );

  // Animation Timer Logic (6-bit counter for smoother timing)
  reg [5:0] frame_count;
  reg laugh_state;
  
  always @(posedge vsync or negedge rst_n) begin
    if (~rst_n) begin
      frame_count <= 0;
      laugh_state <= 0;
    end else begin
      frame_count <= frame_count + 1;
      if (frame_count == 0) laugh_state <= ~laugh_state; // Toggles laugh cycle
    end
  end

  // Vertical Bobbing Offset: Body shifts up by 6 pixels when laughing open-mouthed
  wire [9:0] bounce = laugh_state ? 6 : 0;
  
  // Adjust the drawing coordinates based on the bounce animation
  wire [9:0] adj_y = pix_y + bounce;

  // --- SPONGEBOB GEOMETRY DEFINITIONS ---
  
  // 1. Yellow Sponge Body (Main Block)
  wire is_body       = (pix_x >= 270 && pix_x <= 370 && adj_y >= 160 && adj_y <= 270);
  
  // 2. Sponge Holes (Greenish accents)
  wire is_hole       = (pix_x >= 280 && pix_x <= 290 && adj_y >= 170 && adj_y <= 180) ||
                       (pix_x >= 350 && pix_x <= 360 && adj_y >= 185 && adj_y <= 195) ||
                       (pix_x >= 345 && pix_x <= 355 && adj_y >= 245 && adj_y <= 255) ||
                       (pix_x >= 285 && pix_x <= 292 && adj_y >= 240 && adj_y <= 250);

  // 3. Clothes (Shirt & Pants)
  wire is_shirt      = (pix_x >= 270 && pix_x <= 370 && adj_y >= 271 && adj_y <= 282);
  wire is_pants      = (pix_x >= 270 && pix_x <= 370 && adj_y >= 283 && adj_y <= 305);
  wire is_tie        = (pix_x >= 316 && pix_x <= 324 && adj_y >= 275 && adj_y <= 295);

  // 4. Eyes (White, Blue Iris, Black Pupil)
  wire is_eye_white_l = (pix_x >= 285 && pix_x <= 315 && adj_y >= 185 && adj_y <= 215);
  wire is_eye_white_r = (pix_x >= 325 && pix_x <= 355 && adj_y >= 185 && adj_y <= 215);
  
  wire is_iris_l      = (pix_x >= 297 && pix_x <= 311 && adj_y >= 193 && adj_y <= 207);
  wire is_iris_r      = (pix_x >= 329 && pix_x <= 343 && adj_y >= 193 && adj_y <= 207);
  
  wire is_pupil_l     = (pix_x >= 301 && pix_x <= 307 && adj_y >= 197 && adj_y <= 203);
  wire is_pupil_r     = (pix_x >= 333 && pix_x <= 339 && adj_y >= 197 && adj_y <= 203);

  // 5. Dynamic Animated Mouth & Teeth
  // The mouth shapes change depending on the laugh_state
  wire is_mouth_open  = laugh_state && (pix_x >= 295 && pix_x <= 345 && adj_y >= 225 && adj_y <= 255);
  wire is_mouth_close = !laugh_state && (pix_x >= 305 && pix_x <= 335 && adj_y >= 233 && adj_y <= 242);
  wire is_mouth       = is_mouth_open || is_mouth_close;

  // Two buck teeth visible when mouth is wide open
  wire is_teeth       = laugh_state && (
                        (pix_x >= 308 && pix_x <= 316 && adj_y >= 225 && adj_y <= 235) || 
                        (pix_x >= 324 && pix_x <= 332 && adj_y >= 225 && adj_y <= 235)
                       );

  // --- COLOR GENERATION PIPELINE ---
  reg [5:0] rgb_out;
  
  always @(*) begin
    if (!video_active) begin
      rgb_out = 6'b000000; // Blanking period
    end 
    // Layering priority: Front items first
    else if (is_teeth) begin
      rgb_out = 6'b111111; // White buck teeth
    end 
    else if (is_pupil_l || is_pupil_r) begin
      rgb_out = 6'b000000; // Black pupils
    end 
    else if (is_iris_l || is_iris_r) begin
      rgb_out = 6'b000111; // Ocean blue irises
    end 
    else if (is_eye_white_l || is_eye_white_r) begin
      rgb_out = 6'b111111; // White eyeballs
    end 
    else if (is_mouth) begin
      rgb_out = 6'b100000; // Deep dark red/maroon mouth interior
    end 
    else if (is_tie) begin
      rgb_out = 6'b110000; // Red tie
    end 
    else if (is_pants) begin
      rgb_out = 6'b100100; // Brown square pants (mixed red and green/yellow)
    end 
    else if (is_shirt) begin
      rgb_out = 6'b111111; // Crisp white shirt
    end 
    else if (is_hole) begin
      rgb_out = 6'b101100; // Olive/darker green sponge holes
    end 
    else if (is_body) begin
      rgb_out = 6'b111100; // Classic SpongeBob Yellow
    end 
    else begin
      rgb_out = 6'b001011; // Light blue background sky
    end
  end

  assign {R, G, B} = rgb_out;

  wire _unused_ok = &{ena, ui_in, uio_in};
endmodule