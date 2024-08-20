module data_buf(
	input						wrclock,
	input		[11:0]			wraddress,
	input		[31:0]			data,
	input						wren,
	
	input						rdclock,
	input		[13:0]			rdaddress,
	output		[7:0]			q
);

	reg			[31:0]			mem[0:4095];
	
	always @ (posedge wrclock)
		if(wren) mem[wraddress] <= data;
		
	wire		[31:0]			buf_data;
	assign buf_data = mem[rdaddress[13:2]];
		
	assign q = 
		~|{rdaddress[1:0]} ? buf_data[7:0] :
		rdaddress[0] ? (rdaddress[1] ? buf_data[31:24] : buf_data[15:8]) : buf_data[23:16];

endmodule
