module cmd_fifo(
	input						wrclk,
	input		[31:0]			data,
	input						wrreq,
	output						wrfull,
	
	input						rdclk,
	output		[31:0]			q,
	input						rdreq,
	output						rdempty
	
);
	reg			[31:0]			fifo_data[0:255];
	
	reg			[7:0]			put_ptr;
	initial put_ptr <= 8'd0;
	reg			[7:0]			get_ptr;
	initial get_ptr <= 8'd0;
	reg			[7:0]			fifo_cntr;
	initial fifo_cntr <= 8'd0;
	
	assign rdempty = ~|{fifo_cntr};
	assign wrfull = &{fifo_cntr};
	
	always @ (posedge wrclk)
		if(wrreq && ~wrfull) begin
			fifo_data[put_ptr] <= data;
			put_ptr <= put_ptr + 1'd1;
			fifo_cntr <= fifo_cntr + 1'd1;
		end
		
	always @ (posedge rdclk)
		if(rdreq && ~rdempty) begin
			get_ptr <= get_ptr + 1'd1;
			fifo_cntr <= fifo_cntr - 1'd1;
		end
		
	assign q = fifo_data[get_ptr];
endmodule

