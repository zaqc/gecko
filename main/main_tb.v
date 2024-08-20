module us_tb;

	reg			[0:0]			rst_n;
	reg			[0:0]			sdio_clk;
	reg			[0:0]			hi_clk;
	reg			[0:0]			adc_clk;
	reg			[0:0]			pll_lock;
	
	initial begin
		$display("Start...");
		$display(`TARGET_NAME);
		//$dumpfile("dumpfile_sdrc.vcd");
		$dumpfile({"dumpfile_", `TARGET_NAME, ".vcd"});
		$dumpvars(0);
		pll_lock <= 1'b0;
		rst_n <= 1'b0;
		#12
		rst_n <= 1'b1;
		#10
		pll_lock <= 1'b1;
		#2000000
		$finish();
	end

	initial begin
		sdio_clk <= 1'b0;
		forever begin
			#5
			sdio_clk <= ~sdio_clk;
		end
	end
	
	initial begin
		adc_clk <= 1'b0;
		forever begin
			#27
			adc_clk <= ~adc_clk;
		end
	end
	
	initial begin
		hi_clk <= 1'b0;
		forever begin
			#3
			hi_clk <= ~hi_clk;
		end
	end

	reg			[0:0]			us_clk;
	initial begin
		us_clk <= 1'b0;
		forever begin
			#37
			us_clk <= ~us_clk;
		end
	end
	
	reg			[0:0]			sync;
	initial begin
		sync <= 1'b1;
		#50
		@ (negedge sdio_clk) sync <= 1'b0;
		#200
		@ (negedge sdio_clk) sync <= 1'b1;
		#1500000
		@ (negedge sdio_clk) sync <= 1'b0;
		#200
		@ (negedge sdio_clk) sync <= 1'b1;
		#1500000
		@ (negedge sdio_clk) sync <= 1'b0;
		#200
		@ (negedge sdio_clk) sync <= 1'b1;
	end
	
	wire						st_vld;
	
	reg			[0:0]			rdy;
	initial begin
		rdy <= 1'b1;
		#10100
		rdy <= 1'b0;
		#1000
		rdy <= 1'b1;
	end
	
	reg			[11:0]			adc_data;
	initial begin
		adc_data <= 12'd0;
		forever begin
			@ (posedge sdio_clk) 
				adc_data <= adc_data + 1'd1;
		end
	end
	
	wire		[11:0]			fir_adc_data;
		
	main main_u0(
		.rst_n(rst_n),
		
		.sdio_clk(sdio_clk),
		.hi_clk(hi_clk),
		.adc_clk(adc_clk),
		
		.i_adc_data_0(adc_data)		
	);
	
//	unpack unpack_u0(
//		.rst_n(rst_n),
//		.clk(adc_clk),
//				
//		.i_in_data(32'h89ABCDEF),
//		
//		.i_sdio_rdy(1'b1)
//	);
	
	reg			[0:0]			wrclock;
	reg			[31:0]			wrdata;
	reg			[0:0]			wren;
	reg			[11:0]			wraddr;
	initial begin
		wrclock <= 0;
		wren <= 0;
		#10
		wraddr <= 0;
		wrdata <= 32'h01234567;
		wren <= 1;
		wrclock <= 1;
		#10
		wren <= 0;
		wrclock <= 0;
		#10
		
		wraddr <= 1;
		wrdata <= 32'h89ABCDEF;
		wren <= 1;
		wrclock <= 1;
		#10
		wren <= 0;
		wrclock <= 0;
		#10
		wrclock <= 1;
		#10
		wrclock <= 0;
	end
	
	reg			[14:0]			rdaddr;
	initial begin
		rdaddr <= 0;
		#50
		rdaddr <= 1;
		#50
		rdaddr <= 2;
		#50
		rdaddr <= 3;
		#50
		rdaddr <= 4;
		#50
		rdaddr <= 5;
		#50
		rdaddr <= 6;
		#50
		rdaddr <= 7;
	end
	
//	data_buf data_buf_u0(
//		.wrclock(wrclock),
//		.wraddress(wraddr),
//		.data(wrdata),
//		.wren(wren),
//		
//		.rdaddress(rdaddr)
//	);
	
endmodule
