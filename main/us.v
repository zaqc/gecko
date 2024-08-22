module us(
	input						rst_n,
	input						clk,
	input						hi_clk,
	
	input						i_hw_ch,
	
	input		[31:0]			i_mw0,
	input		[31:0]			i_mw1,
	
	input						i_sync,
	input						i_load_param,
	input						i_sub_sync,
	
	input		[2:0]			i_sub_channel,
	
	output						o_param_done,
	output						o_done,
	
	input						i_wr_half,
		
	output		[9:0]			o_amp_one,
	output		[9:0]			o_amp_two,
	
	output		[7:0]			o_pulse_p,
	output		[7:0]			o_pulse_n,
	
	input		[11:0]			i_adc_data,
	output		[2:0]			o_sel,
	
	input						rd_clk,
	input		[13:0]			i_rd_addr,
	output		[7:0]			o_rd_data,
	
	input		[31:0]			i_cmd_data,
	input						i_cmd_vld
);

// ann-sweer

`include "scan_type.v"

	wire		[7:0]			accum;
	wire		[15:0]			delay;
	wire		[2:0]			scan_type;
	wire		[10:0]			scan_len;
	wire		[2:0]			sel;
	wire		[10:0]			start_amp;
    wire		[9:0]           amp_porch;
	wire		[19:0]			ainc_one;
	wire		[19:0]			ainc_two;
	wire		[15:0]			vrc_len;
	
	wire		[2:0]			pulse_count;
	wire		[2:0]			pulse_mask;
	wire		[7:0]			pulse_width;
	wire		[7:0]			pulse_pause;
	
	wire		[159:0]			pack_param;
	assign pack_param = {accum, delay, scan_type, scan_len, sel, start_amp, amp_porch, ainc_one, ainc_two, 
		vrc_len, pulse_mask, pulse_count, pulse_pause, pulse_width, 20'd0};
	
	us_param us_param_u0(
		.rst_n(rst_n),
		.clk(clk),
		
		.i_hw_ch(i_hw_ch),
		
		.i_sub_channel(i_sub_channel),
		.i_load_param(i_load_param),
		
		.o_accum(accum),
		.o_delay(delay),
		.o_scan_type(scan_type),
		.o_scan_len(scan_len),
		.o_sel(sel),
		.o_start_amp(start_amp),
		.o_amp_porch(amp_porch),
		.o_ainc_one(ainc_one),
		.o_ainc_two(ainc_two),
		.o_vrc_len(vrc_len),
		
		.o_pulse_count(pulse_count),
		.o_pulse_mask(pulse_mask),
		.o_pulse_width(pulse_width),
		.o_pulse_pause(pulse_pause),
		
		.i_cmd_data(i_cmd_data),
		.i_cmd_vld(i_cmd_vld)
	);

	reg			[9:0]			wr_ptr;
	reg			[9:0]			wr_cntr;
	reg			[0:0]			done;
	always @ (posedge clk or negedge rst_n)
		if(~rst_n) begin
			wr_cntr <= 10'd0;
			done <= 1'b1;
		end
		else
			if(i_load_param) 
				wr_cntr <= 10'd0;
			else
				if(i_sub_sync)
					done <= 1'b0;
				else
					if(~done && pack_vld) begin
						if(~&{wr_cntr} && wr_cntr + 1'd1 < scan_len)
							wr_cntr <= wr_cntr + 1'd1;
						else
							done <= 1'b1;							
					end
					
	wire						wren;
	assign wren = ~param_done || (pack_vld & ~done);
			
	always @ (posedge clk or negedge rst_n)
		if(~rst_n)
			wr_ptr <= 10'd0;
		else
			if(i_sync)
				wr_ptr <= 10'd0;
			else
				wr_ptr <= wren ? wr_ptr + 1'd1 : wr_ptr;
			
	reg			[0:0]			param_done;
	reg			[0:0]			first_block;
	reg			[2:0]			param_cntr;
	always @ (posedge clk or negedge rst_n)
		if(~rst_n) begin
			param_done <= 1'b0;
			first_block <= 1'b0;
			param_cntr <= 3'd0;
		end
		else
			if(i_sync)
				first_block <= 1'b1;
			else
				if(i_load_param) begin
					param_done <= 1'b0;
					param_cntr <= 3'd0;
				end
				else
					if(param_cntr < (first_block ? 3'd6 : 3'd4))
						param_cntr <= param_cntr + 1'd1;
					else begin
						param_done <= 1'b1;
						first_block <= 1'b0;
					end
					
	assign o_param_done = param_done;
			
	pulse pulse_u0(
		.rst_n(rst_n),
		.hi_clk(hi_clk),
		
		.i_sync(i_sub_sync),
		
		.i_rx_mask(sel),
		.i_tx_mask(pulse_mask),
		
		.i_pulse_pause(pulse_pause),
		.i_pulse_width(pulse_width),
		.i_pulse_count(pulse_count),
		
		.o_pulse_p(o_pulse_p),
		.o_pulse_n(o_pulse_n)
	);
					
	wire		[9:0]			amp_one;
	wire		[9:0]			amp_two;
	vrc vrc_u0(
		.clk(clk),
		
		.i_sync(i_sub_sync),
		
		.i_start_amp(start_amp),
		.i_amp_porch(amp_porch),
		.i_ainc_one(ainc_one),
		.i_ainc_two(ainc_two),
		.i_vrc_len(vrc_len),
		
		.o_amp_one(amp_one),
		.o_amp_two(amp_two),
		
		.i_process(~done)
	);
	
	assign o_amp_one = amp_one;
	assign o_amp_two = amp_two;

	wire		[11:0]			env_data;
	wire						env_vld;
	env env_u0(
		.rst_n(rst_n),
		.clk(clk),
		
		.i_sync(i_sub_sync),
		
		.i_in_data(i_adc_data),
		
		.i_delay(delay),
		.i_accum(accum),
		.i_scan_type(scan_type),
		.i_amp_one(amp_one),
		.i_amp_two(amp_two),
		
		.o_out_data(env_data),
		.o_out_vld(env_vld)
	);

	wire		[31:0]			pack_data;
	wire						pack_vld;
	pack_ascan pack_ascan_u0(
		.rst_n(rst_n),
		.clk(clk),
		
		.i_sync(i_sub_sync),
		
		.i_in_data(env_data),
		.i_in_vld(env_vld),
		
		.o_out_data(pack_data),
		.o_out_vld(pack_vld),
		.i_out_rdy(1'b1)
	);
	
	wire		[31:0]			wr_data;

	function [31:0] reorder(input [31:0] v);
		reorder = {v[7:0], v[15:8], v[23:16], v[31:24]};
	endfunction
	
	assign wr_data = 
		~param_done ?
			first_block ?				
				param_cntr == 3'd0 ? i_mw0 :
				param_cntr == 3'd1 ? i_mw1 :

				param_cntr == 3'd2 ? pack_param[159:128] :
				param_cntr == 3'd3 ? pack_param[127:96] :
				param_cntr == 3'd4 ? pack_param[95:64] :
				param_cntr == 3'd5 ? pack_param[63:32] :
				param_cntr == 3'd6 ? pack_param[31:0] : pack_data :

				param_cntr == 3'd0 ? pack_param[159:128] :
				param_cntr == 3'd1 ? pack_param[127:96] :
				param_cntr == 3'd2 ? pack_param[95:64] :
				param_cntr == 3'd3 ? pack_param[63:32] :
				param_cntr == 3'd4 ? pack_param[31:0] : pack_data : pack_data;

	data_buf data_buf_u0(
		.wrclock(clk),
		.wraddress({i_wr_half, wr_ptr}),
		.data(wr_data),
		.wren(wren),
		
		.rdclock(rd_clk),
		.rdaddress(i_rd_addr),
		.q(o_rd_data)
	);
	
	assign o_done = done;
	assign o_sel = sel;
endmodule

