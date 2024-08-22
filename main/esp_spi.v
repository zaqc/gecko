module esp_spi (
	input						rst_n,
	
	input						adc_clk,
	
	output		[13:0]			o_mem_addr,
	
	input		[7:0]			i_in_data,
	output						o_in_rdy,
		
	input						spi_clk,
	input						i_spi_cs_n,
	inout		[3:0]			io_spi_data,
	
	output						o_spi_oe,
	
	output		[31:0]			o_out_cmd,
	output						o_out_cmd_vld
);

	reg			[0:0]			spi_half;

	reg			[32:0]			cmd_data;
	
	wire		[32:0]			shift_cmd;
	assign shift_cmd = {cmd_data[31:0], io_spi_data[0]};
	
	reg			[13:0]			mem_addr;
	
	reg			[0:0]			spi_oe;
	
	assign o_spi_oe = spi_oe; //cmd_data[32] && cmd_data[31:24] == 8'h8F;
	
	assign io_spi_data = o_spi_oe ? spi_data_bits : 4'hZ;
	
	wire		[3:0]			spi_data_bits;
	assign spi_data_bits = spi_half ? mem_data[3:0] : i_in_data[7:4];
	
	assign o_in_rdy = cmd_data[32] & o_spi_oe & ~spi_half;
	
	assign o_mem_addr = mem_addr;
	
	wire						cmd_fifo_full;
	wire						cmd_fifo_empty;
//	cmd_fifo cmd_fifo_u0(
//		.wrclk(spi_clk),
//		.wrfull(cmd_fifo_full),
//		.data(shift_cmd[31:0]),
//		.wrreq(shift_cmd[32] & ~cmd_data[32] && shift_cmd[31:24] != 8'h8F && ~cmd_fifo_full),
//		.rdclk(adc_clk),
//		.q(o_out_cmd),
//		.rdempty(cmd_fifo_empty),
//		.rdreq(~cmd_fifo_empty)
//	);
	
	cmd_fifo cmd_fifo_u0(
		.wrclk(spi_clk),
		.wrfull(cmd_fifo_full),
		.data(shift_cmd[31:0]),
		.wrreq(~cmd_fifo_full & shift_cmd[32] & ~cmd_data[32] && (shift_cmd[31:24] != 8'h8F)),
		.rdclk(adc_clk),
		.q(o_out_cmd),
		.rdempty(cmd_fifo_empty),
		.rdreq(~cmd_fifo_empty)
	);

	assign o_out_cmd_vld = ~cmd_fifo_empty; //shift_cmd[32] & ~cmd_data[32] && shift_cmd[23:16] != 8'h81;
	//assign o_out_cmd = o_out_cmd_vld ? shift_cmd[31:0] : 32'hXXXXXXXX;
	
	reg			[7:0]			mem_data;

	always @ (posedge spi_clk or posedge i_spi_cs_n or negedge rst_n)
		if(~rst_n) begin			
			mem_addr <= 14'd0;
			spi_half <= 1'b0;
			cmd_data <= 33'd1;
			mem_data <= 8'd0;
			spi_oe <= 1'b0;
		end
		else
			if(i_spi_cs_n) begin
				mem_addr <= 14'd0;
				spi_half <= 1'b0;
				cmd_data <= 33'd1;
				mem_data <= 8'd0;
				spi_oe <= 1'b0;
			end
			else
				if(~cmd_data[32]) begin
					if(shift_cmd[32]) begin
						if(shift_cmd[31:24] == 8'h8F)
							mem_addr <= shift_cmd[21:8];

						spi_half <= 1'b0;
						mem_data <= i_in_data;
						
						spi_oe <= 1'b1;
					end
					cmd_data <= shift_cmd;
				end
				else 
					if(o_spi_oe)begin
						if(~spi_half) begin
							mem_data <= i_in_data;
							mem_addr <= mem_addr + 1'd1;
						end
						spi_half <= ~spi_half;
					end
endmodule

