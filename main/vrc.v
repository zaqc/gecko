`timescale 1ns/1ps

module vrc(
	input						clk,
	
	input						i_sync,
	
	input		[10:0]			i_start_amp,
    input       [9:0]           i_amp_porch,
	input		[19:0]			i_ainc_one,
	input		[19:0]			i_ainc_two,
	input		[15:0]			i_vrc_len,
	
	output		[9:0]			o_amp_one,
	output		[9:0]			o_amp_two,
	
	input						i_process
);

	reg			[31:0]			vrc;
	reg			[15:0]			vrc_len;
		
	wire						first_half;
	assign first_half = vrc_len < i_vrc_len;
	
	always @ (posedge clk)
		if(i_sync) 
			vrc_len <= 16'd0;
		else
			if(i_process)
				vrc_len <= first_half ? vrc_len + 1'd1 : vrc_len;
				
				
	wire		[31:0]			next_vrc;
	assign next_vrc = first_half ? vrc + i_ainc_one : vrc + i_ainc_two;

	always @ (posedge clk)
		if(i_sync) 
			vrc <= {8'd0, i_start_amp, 13'd0};
		else
			if(i_process)
				vrc <= ~|{next_vrc[31:24]} ? next_vrc : {8'd0, {24{1'b1}}};
			else
				vrc <= {8'd0, i_start_amp, 13'd0};

	wire		[10:0]			amp;
	assign amp = vrc[23:13];

	wire		[9:0]			tmp_amp_one;
	assign tmp_amp_one = ~amp[10] ? amp[9:0] : {10{1'b1}};
	assign o_amp_one = tmp_amp_one < i_amp_porch ? i_amp_porch : tmp_amp_one;

	wire		[10:0]			tmp_amp_two_porch;
	assign tmp_amp_two_porch = 11'd128 + (amp[10] ? amp[9:0] : 10'd0);

	wire		[9:0]			tmp_amp_two_10;
	assign tmp_amp_two_10 = tmp_amp_two_porch[10] ? {10{1'b1}} : tmp_amp_two_porch[9:0];
	assign o_amp_two = tmp_amp_two_10 < i_amp_porch ? i_amp_porch : tmp_amp_two_10;
endmodule

