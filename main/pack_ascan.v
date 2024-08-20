module pack_ascan(
	input						rst_n,
	input						clk,
	
	input						i_sync,
	
	input		[11:0]			i_in_data,
	input						i_in_vld,
	output						o_in_rdy,
	
	output		[31:0]			o_out_data,
	output						o_out_vld,
	input						i_out_rdy
);

	wire						rdy;
	reg			[5:0]			pack_size;
	reg			[39:0]			sreg;

	assign rdy = pack_size[5];

	always @ (posedge clk or negedge rst_n)
		if(~rst_n) 
			pack_size <= 6'd0;
		else
			if(i_sync)
				pack_size <= 6'd0;
			else
				if(rdy) begin
					if(i_out_rdy) begin
						if(i_in_vld) begin
							pack_size <= pack_size - 6'd20;
							sreg <= {sreg[27:0], i_in_data};
						end
						else
							pack_size <= pack_size - 6'd32;
					end
				end
				else
					if(i_in_vld) begin
						pack_size <= pack_size + 6'd12;
						sreg <= {sreg[27:0], i_in_data};
					end
					
	function [31:0] reorder(input [31:0] v);
		reorder = {v[7:0], v[15:8], v[23:16], v[31:24]};
	endfunction

			
	wire		[31:0]			out_data;
	assign out_data = sreg[pack_size - 1 -: 32];

	assign o_out_data = reorder(out_data);
	assign o_out_vld = rdy;
	assign o_in_rdy = ~rdy;
endmodule

