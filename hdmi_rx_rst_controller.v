`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/03/25 09:38:10
// Design Name: 
// Module Name: hdmi_rx_rst_controller
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module hdmi_rx_interface(
    input	wire			clk_50m	,
	input 	wire 			locked 		,
	input 	wire 			hdmi_rx_clk	,//输入时钟
    input     wire             hdmi_rx_de     ,//输入数据有效信号
    input     wire               hdmi_rx_vs    ,//输入场同步信号
    input     wire             hdmi_rx_hs    ,//输入行同步信号
    input     wire     [23:0]    hdmi_rd     ,//输入的解码数据
    output  wire             hdmi_rx_rst ,
    output     wire             hdmi_tx_clk    ,
    output     reg             hdmi_tx_de     ,
    output     reg               hdmi_tx_vs    ,
    output     reg             hdmi_tx_hs    ,
    output     reg     [23:0]    hdmi_td     
		
    );
    parameter       CNT_MAX = 26000000;
   
    reg 	[24:0]	cnt 		;
    wire             rst         ;
    wire             ready         ;
    
    reg     [2:0]    rx_de_dd     ;//输入数据有效信号打三拍
    reg     [2:0]    rx_vs_dd    ;//输入场同步信号打三拍
    reg     [2:0]    rx_hs_dd     ;//输入行同步信号打三拍
    reg     [71:0]    rd_dd         ;//输入数据打三拍
    
    assign rst = ~locked;
    assign hdmi_tx_clk = hdmi_rx_clk;
    assign hdmi_rx_rst = ready;
    
    
    
    
    
    
    always@(posedge clk_50m )begin
        if(locked==1'b0)
            cnt <= 'd0;
        else if(cnt <CNT_MAX)
            cnt <= cnt + 1'b1;
        else
            cnt <= cnt;
    end
    assign  ready = (cnt==CNT_MAX)?1'b1:1'b0;
    
    always @(posedge hdmi_rx_clk) begin
        if (rst==1'b1) begin
            rx_de_dd <=1'b0     ;
            rx_vs_dd <=1'b0    ;
            rx_hs_dd <=1'b0    ;
            rd_dd <='d0    ;
            hdmi_tx_de <= 1'b0    ;//输出数据有效信号
            hdmi_tx_vs <= 1'b0    ;//输出场同步信号
            hdmi_tx_hs <= 1'b0    ;//输出行同步信号
            hdmi_td <='d0;//输出数据
        end
        else begin
            rx_de_dd <= {rx_de_dd[1:0],hdmi_rx_de}     ;
            rx_vs_dd <= {rx_vs_dd[1:0],hdmi_rx_vs}    ;
            rx_hs_dd <= {rx_hs_dd[1:0],hdmi_rx_hs}    ;
            rd_dd <= {rd_dd[47:0],hdmi_rd}    ;
            hdmi_tx_de <= rx_de_dd[2]    ;//输出数据有效信号
            hdmi_tx_vs <= rx_vs_dd[2]    ;//输出场同步信号
            hdmi_tx_hs <= rx_hs_dd[2]    ;//输出行同步信号
            hdmi_td <= rd_dd[71:48];//输出数据
        end
    end

    
endmodule
