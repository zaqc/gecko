module ext_sync(
	input						rst_n,
	input						clk,
	
	input						i_ch_a,
	input						i_ch_b,
	
	input		[7:0]			i_wheel_add,
	input		[7:0]			i_frame_dec,
	
	output						o_ext_sync,
	output		[31:0]			o_way_meter
);

	reg			[1:0]			in_dp;
	always @ (posedge clk) in_dp <= {i_ch_a, i_ch_b};

	reg			[1:0]			unjit_dp;
	reg			[15:0]			unjit_cntr;

	always @ (posedge clk) unjit_dp <= in_dp;

	always @ (posedge clk or negedge rst_n)
		if(~rst_n)
			unjit_cntr <= 16'd0;
		else
			if(unjit_dp == in_dp) begin
				`ifdef TESTMODE
				if(unjit_cntr < 16'd4)
				`else
				if(unjit_cntr < 16'd1000)
				`endif
					unjit_cntr <= unjit_cntr + 16'd1;
				else
					dp <= in_dp;
			end
			else
				unjit_cntr <= 16'd0;
		
	reg			[1:0]			dp;
	reg			[1:0]			prev_dp;

	always @ (posedge clk) prev_dp <= dp;

	reg			[31:0]			wm_cntr;

	reg			[16:0]			brazen_summ;
	reg			[0:0]			sync_pulse;

	always @ (posedge clk or negedge rst_n)
		if(~rst_n) begin
			wm_cntr <= 32'd0;
			brazen_summ <= 16'd0;
			sync_pulse <= 1'b0;
		end
		else
			case({prev_dp, dp})
				4'b0111, 
				4'b1110, 
				4'b1000, 
				4'b0001: begin					
					if(brazen_summ > i_wheel_add)
						brazen_summ <= brazen_summ - i_wheel_add;
					else begin
						brazen_summ <= (brazen_summ + i_frame_dec) - i_wheel_add;
						sync_pulse <= 1'b1;
						wm_cntr <= wm_cntr - 32'd1;
					end
				end
				
				4'b1101,
				4'b0100,
				4'b0010,
				4'b1011: begin					
					if(brazen_summ + i_wheel_add > i_frame_dec) begin
						brazen_summ <= (brazen_summ + i_wheel_add) - i_frame_dec;
						sync_pulse <= 1'b1;
						wm_cntr <= wm_cntr + 32'd1;
					end
					else
						brazen_summ <= brazen_summ + i_wheel_add;
				end
				
				default:
					sync_pulse <= 1'b0;
			endcase
			
	assign o_way_meter = wm_cntr;
	assign o_ext_sync = sync_pulse;

endmodule
