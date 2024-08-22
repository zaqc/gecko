module main(
	input						rst_n,
	
	input						adc_clk,
	input						sdio_clk,
	input						hi_clk,
	
	input						i_ch_a,
	input						i_ch_b,
	
	input						i_sdio_cs_n,
	inout		[3:0]			io_sdio_data,
	
	output						o_esp_irq,
	output						o_esp_flag,
	
	output						o_dac_cs,		// both for all channel
	
	input		[11:0]			i_adc_data_0,
	output		[2:0]			o_sel_0,
	output		[1:0]			o_dac_data_0,
	output		[7:0]			o_pulse_n_0,
	output		[7:0]			o_pulse_p_0,	
	
	input		[11:0]			i_adc_data_1,
	output		[2:0]			o_sel_1,
	output		[1:0]			o_dac_data_1,
	output		[7:0]			o_pulse_n_1,
	output		[7:0]			o_pulse_p_1	
);

	reg			[1:0]			sync_type;
	reg			[23:0]			sync_div;
	reg			[7:0]			wheel_add;
	reg			[7:0]			wheel_dec;
	always @ (posedge adc_clk or negedge rst_n)
		if(~rst_n) begin
			`ifdef TESTMODE
			sync_div <= 24'd24999;
			sync_type <= 2'b01;
			`else
			sync_div <= 24'd249999;
			sync_type <= 2'd01;
			`endif
		end
		else 
			if(esp_cmd_vld && esp_cmd[27:24] == 4'hD)
				case(esp_cmd[31:28])
					4'h1: sync_div <= esp_cmd[23:0];
					4'h2: {wheel_add, wheel_dec} <= esp_cmd[15:0];
					4'h3: sync_type <= esp_cmd[1:0];
				endcase

	reg			[23:0]			sync_cntr;
	reg			[0:0]			int_sync;
	always @ (posedge adc_clk or negedge rst_n)
		if(~rst_n) begin
			`ifdef TESTMODE
			sync_cntr <= 24'd24999;
			`else
			sync_cntr <= 24'd249999;
			`endif
			int_sync <= 1'b0;
		end
		else begin
			int_sync <= 1'b0;
			if(sync_cntr < sync_div)
				sync_cntr <= sync_cntr + 1'd1;
			else begin
				sync_cntr <= 24'd0;
				int_sync <= 1'b1;
			end
		end
		
	wire						ext_sync;
	ext_sync ext_sync_u0(
		.rst_n(rst_n),
		.clk(clk),
		
		.i_ch_a(i_ch_a),
		.i_ch_b(i_ch_b),
		
		.i_wheel_add(wheel_add),
		.i_frame_dec(wheel_dec),
		
		.o_ext_sync(ext_sync),
		.o_way_meter(wheel_counter)
	);
	
	wire						sync;
	assign sync =
		sync_type == 2'b01 ? int_sync :
		sync_type == 2'b10 ? ext_sync : 1'b0;
		
	reg			[0:0]			half;
	always @ (posedge clk or negedge rst_n)
		if(~rst_n)
			half <= 1'b0;
		else
			if(sync)
				half <= ~half;
		
	wire						done_0;
	wire						done_1;
	
	wire		[9:0]			amp_one_0;
	wire		[9:0]			amp_two_0;	
	wire		[9:0]			amp_one_1;
	wire		[9:0]			amp_two_1;
	
	parameter	[3:0]			MS_NONE = 4'd0,
								MS_MAIN_SYNC = 4'd1,
								MS_LOAD_PARAM = 4'd2,
								MS_STORE_PARAM = 4'd3,
								MS_RESET_DAC = 4'd4,
								MS_WAIT_DAC = 4'd5,
								MS_SUB_SYNC = 4'd6,
								MS_STARTED = 4'd7,
								MS_WAIT_DONE = 4'd8;
								
	reg			[3:0]			main_state;

	wire						load_param;
	assign load_param = main_state == MS_LOAD_PARAM;

	wire						sub_sync;
	assign sub_sync = main_state == MS_SUB_SYNC;
	
	
	reg			[3:0]			sub_channal;
	
	wire						param_done_0;
	wire						param_done_1;
	
	reg			[31:0]			packet_countr;
								
	always @ (posedge adc_clk or negedge rst_n)
		if(~rst_n) begin
			main_state <= MS_NONE;
			packet_countr <= 32'd0;
		end
		else begin
			if(sync) begin
				main_state <= MS_MAIN_SYNC;
				sub_channal <= 4'd0;
				packet_countr <= packet_countr + 1'd1;
			end
			else
				case(main_state)
					MS_MAIN_SYNC: main_state <= main_state + 1'd1;
					MS_LOAD_PARAM: main_state <= main_state + 1'd1;
					MS_STORE_PARAM: if(param_done_0 && param_done_1) main_state <= main_state + 1'd1;
					MS_RESET_DAC: if(dac_rdy) main_state <= main_state + 1'd1;
					MS_WAIT_DAC: if(dac_rdy) main_state <= main_state + 1'd1;
					MS_SUB_SYNC: main_state <= main_state + 1'd1;
					MS_STARTED: if(~done_0 && ~done_1) main_state <= main_state + 1'd1;
					MS_WAIT_DONE: 
						if(done_0 && done_1) begin
							if(~&{sub_channal[2:0]})
								main_state <= MS_LOAD_PARAM;
							else
								main_state <= MS_NONE;
								
							sub_channal <= sub_channal + 1'd1;
						end
				endcase
		end
		
	reg			[31:0]			tick_countr;
	reg			[15:0]			tick_div;
	always @ (posedge adc_clk or negedge rst_n)
		if(~rst_n) begin
			tick_div <= 16'd0;
			tick_countr <= 32'd0;
		end
		else
			if(tick_div < 24999)
				tick_div <= tick_div + 1'd1;
			else begin
				tick_countr <= tick_countr + 1'd1;
				tick_div <= 16'd0;
			end
			
	wire		[31:0]			wheel_counter;
	//assign wheel_counter = 32'd0;
	
	wire						dac_rdy;
	dac dac_u0(
		.rst_n(rst_n),
		.clk(adc_clk),
		
		.i_data_0a(amp_one_0),
		.i_data_0b(amp_two_0),
		.i_data_1a(amp_one_1),
		.i_data_1b(amp_two_1),
		
		.o_spi_cs_n(o_dac_cs),
		.o_spi_data_0a(o_dac_data_0[0]),
		.o_spi_data_0b(o_dac_data_0[1]),
		.o_spi_data_1a(o_dac_data_1[0]),
		.o_spi_data_1b(o_dac_data_1[1]),
		
		.i_vld(|{main_state}), //~done_0 || ~done_1),
		.o_rdy(dac_rdy)
	);
		
		
	assign o_esp_irq = sub_channal[3];
	assign o_esp_flag = half;
					
	wire		[13:0]			esp_mem_addr;
	wire		[7:0]			esp_mem_data;
	wire		[31:0]			esp_cmd;
	wire						esp_cmd_vld;
			
	wire		[7:0]			us_mem_data_0;
	us us_0(
		.rst_n(rst_n),
		.clk(adc_clk),
		.hi_clk(hi_clk),
		
		.i_hw_ch(1'b0),
		
		.i_mw0(32'hEC001001),
		.i_mw1(packet_countr),
		
		.i_sync(sync),
		.i_load_param(load_param),
		.i_sub_sync(sub_sync),
		.i_sub_channel(sub_channal[2:0]),
		
		.i_adc_data(i_adc_data_0),
		
		.i_wr_half(half),
		
		.o_param_done(param_done_0),
		.o_done(done_0),

		.o_amp_one(amp_one_0),
		.o_amp_two(amp_two_0),
		
		.o_pulse_n(o_pulse_n_0),
		.o_pulse_p(o_pulse_p_0),
		
		.o_sel(o_sel_0),
		
		.rd_clk(sdio_clk),
		.i_rd_addr(esp_mem_addr[12:0]),
		.o_rd_data(us_mem_data_0),
		
		.i_cmd_data(esp_cmd),
		.i_cmd_vld(esp_cmd_vld)
	);
	
	wire		[7:0]			us_mem_data_1;
	us us_1(
		.rst_n(rst_n),
		.clk(adc_clk),
		.hi_clk(hi_clk),
		
		.i_hw_ch(1'b1),
		
		.i_mw0(tick_countr),
		.i_mw1(wheel_counter),
		
		.i_sync(sync),
		.i_load_param(load_param),
		.i_sub_sync(sub_sync),
		.i_sub_channel(sub_channal[2:0]),
		
		.i_adc_data(i_adc_data_1),
		
		.i_wr_half(half),
		
		.o_param_done(param_done_1),
		.o_done(done_1),
		
		.o_amp_one(amp_one_1),
		.o_amp_two(amp_two_1),
		
		.o_pulse_n(o_pulse_n_1),
		.o_pulse_p(o_pulse_p_1),

		.o_sel(o_sel_1),

		.rd_clk(sdio_clk),
		.i_rd_addr(esp_mem_addr[12:0]),
		.o_rd_data(us_mem_data_1),
		
		.i_cmd_data(esp_cmd),
		.i_cmd_vld(esp_cmd_vld)
	);
	
	assign esp_mem_data = esp_mem_addr[13] ? us_mem_data_1 : us_mem_data_0;
	
	esp_spi esp_spi_u0(
		.rst_n(rst_n),
		
		.adc_clk(adc_clk),
		
		.o_mem_addr(esp_mem_addr),
		
		.i_in_data(esp_mem_data),
		
		.spi_clk(sdio_clk),
		.i_spi_cs_n(i_sdio_cs_n),
		.io_spi_data(io_sdio_data),
		
		.o_out_cmd(esp_cmd),
		.o_out_cmd_vld(esp_cmd_vld)
	);

	`ifndef	TESTMODE
	reg			[31:0]			cmd;
	always @ (posedge adc_clk)
		if(esp_cmd_vld)
			cmd <= esp_cmd;
	
	cmd_probe cmd_probe_u0(.probe(cmd));
	`endif
	
endmodule

