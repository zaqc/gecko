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
	
	wire		[127:0]			pack_param;
	assign pack_param = {accum, delay, scan_type, scan_len, sel, start_amp, amp_porch, ainc_one, ainc_two, vrc_len, 10'd0};
	
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
					if(param_cntr < (first_block ? 3'd5 : 3'd3))
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
		.i_tx_mask(sel),
		
		.i_pulse_width(8'd20),
		.i_pulse_pause(8'd20),
		.i_pulse_count(3'd3),
		
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
	
	assign wr_data = 
		~param_done ?
			first_block ?				
				param_cntr == 3'd0 ? i_mw0 :
				param_cntr == 3'd1 ? i_mw1 :
				param_cntr == 3'd2 ? pack_param[127:96] :
				param_cntr == 3'd3 ? pack_param[95:64] :
				param_cntr == 3'd4 ? pack_param[63:32] :
				param_cntr == 3'd5 ? pack_param[31:0] : pack_data :

				param_cntr == 3'd0 ? pack_param[127:96] :
				param_cntr == 3'd1 ? pack_param[95:64] :
				param_cntr == 3'd2 ? pack_param[63:32] :
				param_cntr == 3'd3 ? pack_param[31:0] : pack_data : pack_data;

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

//module us(
//	input						rst_n,
//	input						clk,
//	input						hi_clk,
//	
//	input						i_hw_ch,
//	
//	input						i_sync,
//	input						i_sub_sync,
//	
//	input		[2:0]			i_sub_channel,
//	
//	output						o_done,
//	
//	input						i_wr_half,
//		
//	output		[9:0]			o_amp_one,
//	output		[9:0]			o_amp_two,
//	
//	output		[7:0]			o_pulse_p,
//	output		[7:0]			o_pulse_n,
//	
//	input		[11:0]			i_adc_data,
//	output		[2:0]			o_sel,
//	
//	input						rd_clk,
//	input		[13:0]			i_rd_addr,
//	output		[7:0]			o_rd_data,
//	
//	input		[31:0]			i_cmd_data,
//	input						i_cmd_vld
//);

//`include "scan_type.v"

//	reg			[7:0]			param_accum[0:7];
//	reg			[15:0]			param_delay[0:7];
//	reg			[2:0]			param_scan_type[0:7];
//	reg			[10:0]			param_scan_len[0:7];
//	reg			[2:0]			param_sel[0:7];
//	reg			[10:0]			param_start_amp[0:7];
//    reg			[9:0]           param_amp_porch[0:7];
//	reg			[19:0]			param_ainc_one[0:7];
//	reg			[19:0]			param_ainc_two[0:7];
//	reg			[15:0]			param_vrc_len[0:7];
//	
//	reg			[7:0]			accum;
//	reg			[15:0]			delay;
//	reg			[2:0]			scan_type;
//	reg			[10:0]			scan_len;
//	reg			[2:0]			sel;
//	reg			[10:0]			start_amp;
//    reg			[9:0]           amp_porch;
//	reg			[19:0]			ainc_one;
//	reg			[19:0]			ainc_two;
//	reg			[15:0]			vrc_len;

//	wire		[2:0]			cmd_ch;
//	assign cmd_ch = i_cmd_data[30:28];
//	
//	wire						cmd_hw_ch;
//	assign cmd_hw_ch = i_cmd_data[31];
//	
//	integer i;
//	always @ (posedge clk or negedge rst_n)
//		if(~rst_n)
//			for(i = 0; i < 8; i = i + 1) begin
//				param_accum[i] <= 8'd10;
//				param_delay[i] <= 16'd0;
//				param_scan_type[i] <= `SCAN_TYPE_GET_VRC; //3'd1;
//				param_scan_len[i] <= 11'd64;
//				param_sel[i] <= i[2:0];
//				param_start_amp[i] <= 11'd0;
//				param_amp_porch[i] <= 10'd40;
//				param_ainc_one[i] <= {10'd20, 10'd0};
//				param_ainc_two[i] <= {10'd8, 10'd0};
//				param_vrc_len[i] <= 16'd150;
//			end
//		else 
//			if(i_cmd_vld && cmd_hw_ch == i_hw_ch)
//				case(i_cmd_data[27:24])
//					4'h1: param_scan_len[cmd_ch] <= i_cmd_data[10:0];
//					4'h5: param_accum[cmd_ch] <= i_cmd_data[7:0];
//					4'h6: param_delay[cmd_ch] <= i_cmd_data[15:0];
//					4'h7: param_scan_type[cmd_ch] <= i_cmd_data[2:0];
//					4'hB: param_sel[cmd_ch] <= i_cmd_data[2:0];
//					4'h9: param_start_amp[cmd_ch] <= i_cmd_data[10:0];
//					4'hA: param_amp_porch[cmd_ch] <= i_cmd_data[9:0];
//					4'h2: param_ainc_one[cmd_ch] <= i_cmd_data[19:0];
//					4'h3: param_ainc_two[cmd_ch] <= i_cmd_data[19:0];
//					4'h4: param_vrc_len[cmd_ch] <= i_cmd_data[15:0];
//				endcase

//	reg			[9:0]			wr_ptr;
//	reg			[9:0]			wr_cntr;
//	reg			[0:0]			done;
//	reg			[2:0]			sub_channel;
//	reg			[0:0]			sub_sync;
//	reg			[0:0]			pulse_sync;
//	always @ (posedge clk or negedge rst_n)
//		if(~rst_n) begin
//			wr_ptr <= 10'd0;
//			wr_cntr <= 10'd0;
//			done <= 1'b1;
//			pulse_sync <= 1'b0;
//		end
//		else
//			if(i_sync) begin
//				wr_ptr <= 10'd0;
//				done <= 1'b1;
//				pulse_sync <= 1'b0;
//			end
//			else begin
//				sub_sync <= 1'b0;
//				pulse_sync <= 1'b0;
//				if(i_sub_sync) begin
//					sub_sync <= 1'b1;
//					sub_channel <= i_sub_channel;
//					//done <= 1'b0;
//					wr_cntr <= 10'd0;
//					accum <= param_accum[i_sub_channel];
//					delay <= param_delay[i_sub_channel];
//					scan_len <= param_scan_len[i_sub_channel];
//					scan_type <= param_scan_type[i_sub_channel];
//					sel <= param_sel[i_sub_channel];
//					start_amp <= param_start_amp[i_sub_channel];
//					amp_porch <= param_amp_porch[i_sub_channel];
//					ainc_one <= param_ainc_one[i_sub_channel];
//					ainc_two <= param_ainc_two[i_sub_channel];
//					vrc_len <= param_vrc_len[i_sub_channel];
//				end
//				else
//					if(sub_sync) begin
//						done <= 1'b0;
//						pulse_sync <= 1'b1;
//					end
//					else
//						if(~done && pack_vld) begin
//							if(~&{wr_cntr} && wr_cntr + 1'd1 < scan_len) begin
//								wr_cntr <= wr_cntr + 1'd1;
//								wr_ptr <= wr_ptr + 1'd1;
//							end
//							else begin
//								wr_ptr <= wr_ptr + 1'd1;
//								done <= 1'b1;
//							end
//						end
//			end
//			
//	pulse pulse_u0(
//		.rst_n(rst_n),
//		.hi_clk(hi_clk),
//		
//		.i_sync(pulse_sync),
//		
//		.i_rx_mask(sel),
//		.i_tx_mask(sel),
//		
//		.i_pulse_width(8'd20),
//		.i_pulse_pause(8'd20),
//		.i_pulse_count(3'd3),
//		
//		.o_pulse_p(o_pulse_p),
//		.o_pulse_n(o_pulse_n)
//	);
//					
//	wire		[9:0]			amp_one;
//	wire		[9:0]			amp_two;
//	vrc vrc_u0(
//		.clk(clk),
//		
//		.i_sync(sub_sync),
//		
//		.i_start_amp(start_amp),
//		.i_amp_porch(amp_porch),
//		.i_ainc_one(ainc_one),
//		.i_ainc_two(ainc_two),
//		.i_vrc_len(vrc_len),
//		
//		.o_amp_one(amp_one),
//		.o_amp_two(amp_two),
//		
//		.i_process(~done)
//	);
//	
//	assign o_amp_one = amp_one;
//	assign o_amp_two = amp_two;

//	wire		[11:0]			env_data;
//	wire						env_vld;
//	env env_u0(
//		.rst_n(rst_n),
//		.clk(clk),
//		
//		.i_sync(sub_sync),
//		
//		.i_in_data(i_adc_data),
//		
//		.i_delay(delay),
//		.i_accum(accum),
//		.i_scan_type(scan_type),
//		.i_amp_one(amp_one),
//		.i_amp_two(amp_two),
//		
//		.o_out_data(env_data),
//		.o_out_vld(env_vld)
//	);

//	wire		[31:0]			pack_data;
//	wire						pack_vld;
//	pack_ascan pack_ascan_u0(
//		.rst_n(rst_n),
//		.clk(clk),
//		
//		.i_sync(sub_sync),
//		
//		.i_in_data(env_data),
//		.i_in_vld(env_vld),
//		
//		.o_out_data(pack_data),
//		.o_out_vld(pack_vld),
//		.i_out_rdy(1'b1)
//	);

//	data_buf data_buf_u0(
//		.wrclock(clk),
//		.wraddress({i_wr_half, wr_ptr}),
//		.data(pack_data),
//		.wren(pack_vld & ~done),
//		
//		.rdclock(rd_clk),
//		.rdaddress(i_rd_addr),
//		.q(o_rd_data)
//	);
//	
//	assign o_done = done;
//	assign o_sel = sel;
//endmodule

