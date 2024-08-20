module env(
	input						rst_n,
	input						clk,
		
	input						i_sync,
		
	input signed		
				[11:0]			i_in_data,
	
	input		[15:0]			i_delay,
	input		[7:0]			i_accum,
	input		[2:0]			i_scan_type,
	
	output		
	signed		[11:0]			o_out_data,
	output						o_out_vld,
	
	input		[9:0]			i_amp_one,
	input		[9:0]			i_amp_two
);

`include "scan_type.v"

	reg			[7:0]			accum_cntr;
	
	wire						accum_done;
	assign accum_done = accum_cntr + 1'd1 >= i_accum;
	
	always @ (posedge clk)
		if(i_sync)
			accum_cntr <= 8'd0;
		else
			accum_cntr <= accum_done ? 8'd0 : accum_cntr + 1'd1;

	wire						accum_start;
	assign accum_start = ~|{accum_cntr};
	
	wire signed	[11:0]			in_data;
	assign in_data = i_in_data;
				
	wire		[11:0]			abs_in_data;
	assign abs_in_data = in_data[11] ? -in_data : in_data;
	
	reg signed	[11:0]			max;
	wire		[11:0]			abs_max;
	assign abs_max = max[11] ? -max : max;

	reg	signed	[11:0]			res;
	
	reg			[18:0]			summ;
	reg			[0:0]			data_vld;
	always @ (posedge clk) begin
		data_vld <= 1'b0;
		case(i_scan_type)
			`SCAN_TYPE_GET_MAX:
				if(accum_start) begin
					if(accum_done) begin
						res <= in_data;
						data_vld <= 1'b1;
					end
					else
						max <= in_data;
				end
				else
					if(accum_done) begin
						res <= abs_max < abs_in_data ? in_data : max;
						data_vld <= 1'b1;
					end
					else
						max <= abs_max < abs_in_data ? in_data : max;
				
			`SCAN_TYPE_GET_MED:
				if(accum_start) begin
					if(accum_done) begin						
						res <= abs_in_data;
						data_vld <= 1'b1;
					end
					else
						summ <= abs_in_data;
				end
				else
					if(accum_done) begin
						res <= (summ + abs_in_data) / (i_accum + 1);
						data_vld <= 1'b1;
					end
					else
						summ <= summ + abs_in_data;
						
			`SCAN_TYPE_GET_FIRST:
				if(accum_done) begin
					res <= in_data;
					data_vld <= 1'b1;
				end
										
			`SCAN_TYPE_GET_VRC:
				if(accum_done) begin
					res <= i_amp_one + i_amp_two;
					data_vld <= 1'b1;
				end
		endcase
	end
					
	reg			[15:0]			delay;
	wire		[15:0]			next_delay;
	assign next_delay = delay + 1'd1;
	wire						delay_done;
	assign delay_done = next_delay >= i_delay;
	always @ (posedge clk)
		if(i_sync)
			delay <= 16'd0;
		else
			delay <= delay_done ? delay : next_delay;
		
	assign o_out_data = res;
	assign o_out_vld = delay_done & data_vld ? 1'b1 : 1'b0;

endmodule

