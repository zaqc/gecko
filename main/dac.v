`timescale 1ns/1ps

module dac(
	input						rst_n,
	input						clk,
	
	input		[9:0]			i_data_0a,
	input		[9:0]			i_data_0b,
	input		[9:0]			i_data_1a,
	input		[9:0]			i_data_1b,
	input						i_vld,
	output						o_rdy,
	
	output						o_spi_cs_n,
	output						o_spi_data_0a,
	output						o_spi_data_0b,
	output						o_spi_data_1a,
	output						o_spi_data_1b
);

	reg			[4:0]			cntr;
	reg			[15:0]			sreg_0a;
	reg			[15:0]			sreg_0b;
	reg			[15:0]			sreg_1a;
	reg			[15:0]			sreg_1b;
	
	assign o_rdy = cntr[4] & rst_n;

	always @ (posedge clk or negedge rst_n)
		if(~rst_n)
			cntr <= 5'h10;
		else
			if(o_rdy & i_vld) begin
				sreg_0a <= {4'd0, i_data_0a, 2'd0};
				sreg_0b <= {4'd0, i_data_0b, 2'd0};
				sreg_1a <= {4'd0, i_data_1a, 2'd0};
				sreg_1b <= {4'd0, i_data_1b, 2'd0};
				cntr <= 5'd0;
			end
			else begin
				sreg_0a <= {sreg_0a[14:0], 1'b0};
				sreg_0b <= {sreg_0b[14:0], 1'b0};
				sreg_1a <= {sreg_1a[14:0], 1'b0};
				sreg_1b <= {sreg_1b[14:0], 1'b0};
				cntr <= o_rdy ? cntr : cntr + 1'd1;
			end
			
	assign o_spi_cs_n = o_rdy;
	assign o_spi_data_0a = sreg_0a[15];
	assign o_spi_data_0b = sreg_0b[15];
	assign o_spi_data_1a = sreg_1a[15];
	assign o_spi_data_1b = sreg_1b[15];

endmodule
