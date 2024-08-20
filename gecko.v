module gecko(
	//system
	input 						clk50,
	
	//ESP32 interface
	input 						esp_clk,
	input 						esp_cmd,
	inout		[3:0] 			esp_sd,
	output						esp_half,
	output						esp_sync,
	
	//synchronization
	input 						sync_ina,
	input 						sync_inb,
	
	//test_led
	output 						led,
	
	//channals common
	output						mclk_adc,	//adc_clock
	output						sclk_dac,	//dac_clock
	output						syncn_dac,	//dac cs
	output		[1:0]			cc,			//znd current control
	
	//channal 0 data
	input 		[11:0]			d0x,
	//channal 0 select
	output 		[2:0]			sel0x,
	//channal 0 dac data
	output		[1:0]			din_dac0x,
	
	//channal 1 data
	input		[11:0]			d1x,
	//channal 1 select
	output		[2:0]			sel1x,
	//channal 1 dac data
	output		[1:0]			din_dac1x,
	
	//channal 0 znd
	output		[7:0]			dinn0x,
	output		[7:0]			dinp0x,
	
	//channal 1 znd
	output		[7:0]			dinn1x,
	output		[7:0]			dinp1x
);
	
	wire						adc_clk;
	wire						hi_clk;
	wire						rst_n;
	main_pll Main_pll_unit(
		.inclk0(clk50),
		.c0(adc_clk),
		.c1(hi_clk),
		.locked(rst_n)
	);
	
	assign mclk_adc = adc_clk;
	assign sclk_dac = adc_clk;
	
	assign cc = 2'b11;
		
	main main_gecko_unit(
		.rst_n(rst_n),
		
		.sdio_clk(esp_clk),
		.adc_clk(adc_clk),
		.hi_clk(hi_clk),
		
		.o_esp_irq(esp_sync),
		.o_esp_flag(esp_half),
		
		.i_sdio_cs_n(esp_cmd),
		.io_sdio_data(esp_sd),
		
		.o_dac_cs(syncn_dac),
		
		.i_adc_data_0(d0x),
		//.i_adc_data_0(12'h123)
		.o_sel_0(sel0x),
		.o_dac_data_0(din_dac0x),
		.o_pulse_n_0(dinn0x),
		.o_pulse_p_0(dinp0x),
		
		.i_adc_data_1(d1x),
		//.i_adc_data_1(12'h456),
		.o_sel_1(sel1x),
		.o_dac_data_1(din_dac1x),
		.o_pulse_n_1(dinn1x),
		.o_pulse_p_1(dinp1x)
	);
	
//	assign dinn0x = 8'hFF;
//	assign dinp0x = 8'hFF;
//	assign dinn1x = 8'hFF;
//	assign dinp1x = 8'hFF;
		
endmodule
