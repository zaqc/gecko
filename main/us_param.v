module us_param(
	input						rst_n,
	input						clk,
	
	input						i_hw_ch,

	input		[2:0]			i_sub_channel,
	input						i_load_param,
	
	output		[7:0]			o_accum,
	output		[15:0]			o_delay,
	output		[2:0]			o_scan_type,
	output		[10:0]			o_scan_len,
	output		[2:0]			o_sel,
	output		[10:0]			o_start_amp,
    output		[9:0]           o_amp_porch,
	output		[19:0]			o_ainc_one,
	output		[19:0]			o_ainc_two,
	output		[15:0]			o_vrc_len,

	input		[31:0]			i_cmd_data,
	input						i_cmd_vld
);

	reg			[7:0]			param_accum[0:7];
	reg			[15:0]			param_delay[0:7];
	reg			[2:0]			param_scan_type[0:7];
	reg			[10:0]			param_scan_len[0:7];
	reg			[2:0]			param_sel[0:7];
	reg			[10:0]			param_start_amp[0:7];
    reg			[9:0]           param_amp_porch[0:7];
	reg			[19:0]			param_ainc_one[0:7];
	reg			[19:0]			param_ainc_two[0:7];
	reg			[15:0]			param_vrc_len[0:7];
	
	reg			[7:0]			accum;
	reg			[15:0]			delay;
	reg			[2:0]			scan_type;
	reg			[10:0]			scan_len;
	reg			[2:0]			sel;
	reg			[10:0]			start_amp;
    reg			[9:0]           amp_porch;
	reg			[19:0]			ainc_one;
	reg			[19:0]			ainc_two;
	reg			[15:0]			vrc_len;
	
	assign o_accum = accum;
	assign o_delay = delay;
	assign o_scan_type = scan_type;
	assign o_scan_len = scan_len;
	assign o_sel = sel;
	assign o_start_amp = start_amp;
	assign o_amp_porch = amp_porch;
	assign o_ainc_one = ainc_one;
	assign o_ainc_two = ainc_two;
	assign o_vrc_len = vrc_len;

	wire		[2:0]			cmd_ch;
	assign cmd_ch = i_cmd_data[30:28];
	
	wire						cmd_hw_ch;
	assign cmd_hw_ch = i_cmd_data[31];
	
	integer i;
	always @ (posedge clk or negedge rst_n)
		if(~rst_n)
			for(i = 0; i < 8; i = i + 1) begin
				param_accum[i] <= 8'd10;
				param_delay[i] <= 16'd0;
				param_scan_type[i] <= 3'd1; //`SCAN_TYPE_GET_VRC; //3'd1;
				param_scan_len[i] <= 11'd64;
				param_sel[i] <= i[2:0];
				param_start_amp[i] <= 11'd0;
				param_amp_porch[i] <= 10'd40;
				param_ainc_one[i] <= {10'd20, 10'd0};
				param_ainc_two[i] <= {10'd8, 10'd0};
				param_vrc_len[i] <= 16'd150;
			end
		else 
			if(i_cmd_vld && cmd_hw_ch == i_hw_ch)
				case(i_cmd_data[27:24])
					4'h1: param_scan_len[cmd_ch] <= i_cmd_data[10:0];
					4'h5: param_accum[cmd_ch] <= i_cmd_data[7:0];
					4'h6: param_delay[cmd_ch] <= i_cmd_data[15:0];
					4'h7: param_scan_type[cmd_ch] <= i_cmd_data[2:0];
					4'hB: param_sel[cmd_ch] <= i_cmd_data[2:0];
					4'h9: param_start_amp[cmd_ch] <= i_cmd_data[10:0];
					4'hA: param_amp_porch[cmd_ch] <= i_cmd_data[9:0];
					4'h2: param_ainc_one[cmd_ch] <= i_cmd_data[19:0];
					4'h3: param_ainc_two[cmd_ch] <= i_cmd_data[19:0];
					4'h4: param_vrc_len[cmd_ch] <= i_cmd_data[15:0];
				endcase

	always @ (posedge clk)
		if(i_load_param) begin
			accum <= param_accum[i_sub_channel];
			delay <= param_delay[i_sub_channel];
			scan_len <= param_scan_len[i_sub_channel];
			scan_type <= param_scan_type[i_sub_channel];
			sel <= param_sel[i_sub_channel];
			start_amp <= param_start_amp[i_sub_channel];
			amp_porch <= param_amp_porch[i_sub_channel];
			ainc_one <= param_ainc_one[i_sub_channel];
			ainc_two <= param_ainc_two[i_sub_channel];
			vrc_len <= param_vrc_len[i_sub_channel];
		end

endmodule
