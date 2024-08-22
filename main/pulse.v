module pulse(
	input						rst_n,
	input						hi_clk,
	
	input						i_sync,
	
	input		[2:0]			i_rx_mask,
	input		[2:0]			i_tx_mask,
	input		[2:0]			i_pulse_count,
	input		[7:0]			i_pulse_width,	// High state
	input		[7:0]			i_pulse_pause,	// Low state
	
	output		[7:0]			o_pulse_p,
	output		[7:0]			o_pulse_n
);

	reg			[2:0]			pulse_state;
	parameter	[2:0]			PS_NONE = 3'd0,
								PS_P_HI_STATE = 3'd1,
								PS_P_LO_STATE = 3'd2,
								PS_N_HI_STATE = 3'd3,
								PS_N_LO_STATE = 3'd4,
								PS_RST = 3'd5;
	
	reg			[2:0]			cntr;
	reg			[7:0]			width;
	
	reg			[1:0]			sync_latch;
	initial sync_latch <= 2'd0;
	always @ (posedge hi_clk)
		sync_latch <= {sync_latch[0], i_sync};
		
	wire						hi_sync;
	assign hi_sync = sync_latch == 2'b01;

	always @ (posedge hi_clk or negedge rst_n)
		if(~rst_n) begin
			pulse_state <= PS_RST;
			cntr <= 3'd0;
			width <= 8'd0;
		end
		else
			if(hi_sync && |{i_pulse_count}) begin
				pulse_state <= PS_P_HI_STATE;
				cntr <= 3'd0;
				width <= 8'd0;
			end
			else
				if(|{pulse_state} && pulse_state != PS_RST) begin
					if((pulse_state[0] && (width < i_pulse_width)) || (~pulse_state[0] && (width < i_pulse_pause)))
						width <= width + 1'd1;
					else begin
						width <= 8'd0;
						if(pulse_state[2]) begin	// pulse_state == PS_N_LO_STATE
							pulse_state <= cntr + 1'd1 < i_pulse_count ? PS_P_HI_STATE : PS_NONE;
							cntr <= cntr + 1'd1;
						end
						else
							pulse_state <= pulse_state + 1'd1;
					end
				end
				
	assign o_pulse_p =
		pulse_state == PS_RST ? 8'h00 :
		pulse_state == PS_NONE ? 1'b1 << i_rx_mask :
		pulse_state == PS_P_HI_STATE ? 1'b1 << i_tx_mask : 8'h00;
		
	assign o_pulse_n =
		pulse_state == PS_RST ? 8'h00 :
		pulse_state == PS_NONE ? 1'b1 << i_rx_mask :
		pulse_state == PS_N_HI_STATE ? 1'b1 << i_tx_mask : 8'h00;
		
endmodule
