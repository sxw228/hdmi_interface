// --------------------------------------------------------------------
// Copyright (c) 2019 by MicroPhase Technologies Inc. 
// --------------------------------------------------------------------
//
// Permission:
//
//   MicroPhase grants permission to use and modify this code for use
//   in synthesis for all MicroPhase Development Boards.
//   Other use of this code, including the selling 
//   ,duplication, or modification of any portion is strictly prohibited.
//
// Disclaimer:
//
//   This VHDL/Verilog or C/C++ source code is intended as a design reference
//   which illustrates how these types of functions can be implemented.
//   It is the user's responsibility to verify their design for
//   consistency and functionality through the use of formal
//   verification methods.  MicroPhase provides no warranty regarding the use 
//   or functionality of this code.
//
// --------------------------------------------------------------------
//           
//                     MicroPhase Technologies Inc
//                     Shanghai, China
//
//                     web: http://www.microphase.cn/   
//                     email: support@microphase.cn
//
// --------------------------------------------------------------------
// --------------------------------------------------------------------
//
// Major Functions:	
//
// --------------------------------------------------------------------
// --------------------------------------------------------------------
//
//  Revision History:
//  Date          By            Revision    Change Description
//---------------------------------------------------------------------
//2019-12-07      Chaochen Wei  1.0          Original
//2019/                         1.1          
// --------------------------------------------------------------------
// --------------------------------------------------------------------

module  i2c_cfg(
    input   wire            clk         ,//输入时钟
    input   wire            rst         ,//系统复位
    output  wire            scl         ,//i2c时钟
    inout   wire            sda          //i2c数据
);


//==================================================
//parameter define
//==================================================
parameter   IDLE    =   4'b0001;
parameter   WR_CHECK=   4'b0010;
parameter   WRITE   =   4'b0100;
parameter   READ    =   4'b1000;

parameter   SYS_CYCLE   = 20;//系统时钟50M
parameter   WAIT_TIME   =  20000000;//两次传输数据的等待时间
parameter   CNT_MAX    = 25000_000 - 1;
parameter   MAX_WAIT    =   WAIT_TIME/SYS_CYCLE - 1; 

parameter   DEV_ADDR    =   8'h72;

//==================================================
//internal signals
//==================================================

reg             rd_req    	;//i2c读请求
wire            rd_done		;//i2c读响应
wire    [7:0]   rd_data   	;//i2c读出的数据
reg             wr_req   	;//i2c写请求
wire            wr_done		;//i2c写响应
wire    [7:0]   wr_data  	;//i2c写入的数据
wire    [7:0]   dev_addr	;//i2c从设备地址
wire    [7:0]   mem_addr	;//i2c从设备寄存器地址
wire            err_flag    ;//错误信号

reg     [24:0]  cnt_wait    ;
reg             ready       ;//准备好信号


reg     [3:0]   state           ;//state register
reg     [8:0]   wr_index        ;//配置寄存器索引  
reg     [8:0]   rd_index        ;//读取寄存器索引
reg     [23:0]  lut_data        ;//配置寄存器值
reg             cfg_done        ;//配置完成  
reg             start           ;//读写起始信号  
wire 			done 			;
reg 	[24:0]	cnt 			;      

always@(posedge clk )begin
    if(rst==1'b1)
        cnt <= 'd0;
    else if(lut_data=='h98FF80 || lut_data=='h6CFFDA)begin 
        if(cnt ==CNT_MAX)
            cnt <= 'd0;
        else
            cnt <= cnt + 1'b1;
    end
    else
        cnt <= 'd0;
end

assign  done = (cnt==CNT_MAX)?1'b1:1'b0;
//--------------------state machine describe--------------------
always @(posedge clk)begin
    if(rst == 1'b1)begin
        state <= IDLE;
    end
    else begin
        case(state)
            IDLE:begin
                    state <= WR_CHECK;
            end

            WR_CHECK:begin  //判断当前是否已经配置完成寄存器，若是则等待读寄存器，若不是则进入WRITE状态，写寄存器
                if(cfg_done==1'b0 && ready)
                    state <= WRITE;
                else if(cfg_done==1'b1 && ready)
                    state <= READ;
            end

            WRITE:begin//一个寄存器写完，回到WR_CHECK状态
                if(wr_done)
                    state <= WR_CHECK;
                else if(done)
                	state <= WR_CHECK;
                else if(cfg_done==1'b1)
                    state <= WR_CHECK;
                else
                    state <= WRITE;
            end  

            READ:begin//读寄存器完成，回到IDLE状态
                if(rd_done)
                    state <= WR_CHECK;
                else
                    state <= READ;
            end

            default:begin
                state <= IDLE;
            end
        endcase
    end
end

//--------------------cnt_wait--------------------
always @(posedge clk)begin
    if(rst == 1'b1)begin
        cnt_wait <= 'd0;//复位
    end
    else if(state==WR_CHECK)begin//等待状态或者写判断是否配置完成状态
        if(cnt_wait==MAX_WAIT)
            cnt_wait <= 'd0;
        else
            cnt_wait <= cnt_wait + 1'b1;
    end  
    else begin
        cnt_wait <= 'd0;
    end
end

//--------------------ready--------------------
always @(posedge clk)begin
    if(rst == 1'b1)begin
        ready <= 1'b0;
    end
    else if(state==WR_CHECK)begin//读到最后一个寄存器，索引值保持不变
        if(cnt_wait==MAX_WAIT)
            ready <= 1'b1;
        else
            ready <= ready;
    end
    else if(start)begin
        ready <= 1'b0; 
    end
end

always @(posedge clk)begin
    if(rst == 1'b1)begin
        lut_data <= 'ha00100;
    end
    else if(cfg_done==1'b0)begin
        case(wr_index)//配置寄存器列表
        	9'd0       :   lut_data <= 24'h98FF80  ;
            //9'd0       :   lut_data <= 24'h98F480  ;
			9'd1       :   lut_data <= 24'h98F480  ; //CEC
			9'd2       :   lut_data <= 24'h98F57C  ; //INFOFRAME
			9'd3       :   lut_data <= 24'h98F84C  ; //DPLL
			9'd4       :   lut_data <= 24'h98F964  ; //KSV
			9'd5       :   lut_data <= 24'h98FA6C  ; //EDID
			9'd6       :   lut_data <= 24'h98FB68  ; //HDMI
			9'd7       :   lut_data <= 24'h98FD44  ; //CP
			9'd8       :   lut_data <= 24'h980106  ; //Prim_Mode <=110b HDMI-GR
			9'd9       :   lut_data <= 24'h9802F2  ; //Auto CSC, YCrCb out, Set op_656 bit
			9'd10      :   lut_data <= 24'h980340  ; //24 bit SDR 444 Mode 0
			9'd11      :   lut_data <= 24'h980462  ;
			9'd12      :   lut_data <= 24'h980528 ; //AV Codes Off
			9'd13      :   lut_data <= 24'h9806A0 ; //Invert VS,HS pins
			9'd14      :   lut_data <= 24'h980B44 ; //Power up part
			9'd15      :   lut_data <= 24'h980C42 ; //Power up part
			9'd16      :   lut_data <= 24'h98147F ; //Max Drive Strength
			9'd17      :   lut_data <= 24'h981580 ; //Disable Tristate of Pins
			9'd18      :   lut_data <= 24'h981983 ; //LLC DLL phase
			9'd19      :   lut_data <= 24'h983340 ; //LLC DLL enable
			9'd20      :   lut_data <= 24'h44BA01 ; //Set HDMI FreeRun
			9'd21      :   lut_data <= 24'h644081 ; //Disable HDCP 1.1 features
			9'd22      :   lut_data <= 24'h689B03 ; //ADI recommended setting
			9'd23      :   lut_data <= 24'h68C101 ; //ADI recommended setting
			9'd24      :   lut_data <= 24'h68C201 ; //ADI recommended setting
			9'd25      :   lut_data <= 24'h68C301 ; //ADI recommended setting
			9'd26      :   lut_data <= 24'h68C401 ; //ADI recommended setting
			9'd27      :   lut_data <= 24'h68C501 ; //ADI recommended setting
			9'd28      :   lut_data <= 24'h68C601 ; //ADI recommended setting
			9'd29      :   lut_data <= 24'h68C701 ; //ADI recommended setting
			9'd30      :   lut_data <= 24'h68C801 ; //ADI recommended setting
			9'd31      :   lut_data <= 24'h68C901 ; //ADI recommended setting
			9'd32      :   lut_data <= 24'h68CA01 ; //ADI recommended setting
			9'd33      :   lut_data <= 24'h68CB01 ; //ADI recommended setting
			9'd34      :   lut_data <= 24'h68CC01 ; //ADI recommended setting
			9'd35      :   lut_data <= 24'h680000 ; //Set HDMI Input Port A
			9'd36      :   lut_data <= 24'h6883FE ; //Enable clock terminator for port A
			9'd37      :   lut_data <= 24'h686F0C ; //ADI recommended setting
			9'd38      :   lut_data <= 24'h68851F ; //ADI recommended setting
			9'd39      :   lut_data <= 24'h688770 ; //ADI recommended setting
			9'd40      :   lut_data <= 24'h688D04 ; //LFG
			9'd41      :   lut_data <= 24'h688E1E ; //HFG
			9'd42      :   lut_data <= 24'h681A8A ; //unmute audio
			9'd43      :   lut_data <= 24'h6857DA ; //ADI recommended setting
			9'd44      :   lut_data <= 24'h685801 ; //ADI recommended setting
			9'd45      :   lut_data <= 24'h680398 ; //DIS_I2C_ZERO_COMPR
			9'd46      :   lut_data <= 24'h687510 ; //DDC drive strength
		
			9'd47      :   lut_data <= 24'h720100 ; //Set N Value(6144)
			9'd48      :   lut_data <= 24'h720218 ; //Set N Value(6144)
			9'd49      :   lut_data <= 24'h720300 ; //Set N Value(6144)
			9'd50      :   lut_data <= 24'h721510 ; //Input 444 (RGB or YCrCb) with Separate Syncs, 44.1kHz fs
			9'd51      :   lut_data <= 24'h721630 ; //Output format 444, 24-bit input
			9'd52      :   lut_data <= 24'h721846 ; //CSC disabled
			9'd53      :   lut_data <= 24'h724080 ; //General Control packet enable
			9'd54      :   lut_data <= 24'h724110 ; //Power down control
			9'd55      :   lut_data <= 24'h7249A8 ; //Data right justified
			9'd56      :   lut_data <= 24'h725510 ; //Set Dither_mode - 12-to-10 bit
			9'd57      :   lut_data <= 24'h725608 ; //8 bit Output
			9'd58      :   lut_data <= 24'h7296F6 ; //Set YCrCb 444 in AVinfo Frame
			9'd59      :   lut_data <= 24'h727307 ; //Set active format Aspect
			9'd60      :   lut_data <= 24'h72761F ; //HPD Interrupt clear
			9'd61      :   lut_data <= 24'h729803 ; //ADI Recommended Write
			9'd62      :   lut_data <= 24'h729902 ; //ADI Recommended Write
			9'd63      :   lut_data <= 24'h729C30 ; //PLL Filter R1 Value
			9'd64      :   lut_data <= 24'h729D61 ; //Set clock divide
			9'd65      :   lut_data <= 24'h72A2A4 ; //ADI Recommended Write
			9'd66      :   lut_data <= 24'h72A3A4 ; //ADI Recommended Write
			9'd67      :   lut_data <= 24'h72A504 ; //ADI Recommended Write
			9'd68      :   lut_data <= 24'h72AB40 ; //ADI Recommended Write
			9'd69      :   lut_data <= 24'h72AF16 ; //Set HDMI Mode
			9'd70      :   lut_data <= 24'h72BA60 ; //No clock delay
			9'd71      :   lut_data <= 24'h72D1FF ; //ADI Recommended Write
			9'd72      :   lut_data <= 24'h72DE10 ; //ADI Recommended Write
			9'd73      :   lut_data <= 24'h72E460 ; //VCO_Swing_Reference_Voltage
			9'd74      :   lut_data <= 24'h72FA7D ; //Nbr of times to search for good phase
			
			9'd75      :   lut_data <= 24'h647700 ; //Disable the Internal EDID
			9'd76      :   lut_data <= 24'h647400 ; //Disable the Internal EDID
			9'd77      :   lut_data <= 24'h6C0000 ; 
			9'd78      :   lut_data <= 24'h6C01FF ; 
			9'd79      :   lut_data <= 24'h6C02FF ; 
			9'd80      :   lut_data <= 24'h6C03FF ; 
			9'd81      :   lut_data <= 24'h6C04FF ; 
			9'd82      :   lut_data <= 24'h6C05FF ; 
			9'd83      :   lut_data <= 24'h6C06FF ; 
			9'd84      :   lut_data <= 24'h6C0700 ; 
			9'd85      :   lut_data <= 24'h6C0806 ; 
			9'd86      :   lut_data <= 24'h6C098F ; 
			9'd87      :   lut_data <= 24'h6C0A07 ; 
			9'd88      :   lut_data <= 24'h6C0B11 ; 
			9'd89      :   lut_data <= 24'h6C0C01 ; 
			9'd90      :   lut_data <= 24'h6C0D00 ; 
			9'd91      :   lut_data <= 24'h6C0E00 ; 
			9'd92      :   lut_data <= 24'h6C0F00 ; 
			9'd93      :   lut_data <= 24'h6C1017 ; 
			9'd94      :   lut_data <= 24'h6C1111 ; 
			9'd95      :   lut_data <= 24'h6C1201 ; 
			9'd96      :   lut_data <= 24'h6C1303 ; 
			9'd97      :   lut_data <= 24'h6C1480 ; 
			9'd98      :   lut_data <= 24'h6C150C ; 
			9'd99      :   lut_data <= 24'h6C1609 ; 
			9'd100     :   lut_data <= 24'h6C1778 ; 
			9'd101     :   lut_data <= 24'h6C180A ; 
			9'd102     :   lut_data <= 24'h6C191E ; 
			9'd103     :   lut_data <= 24'h6C1AAC ; 
			9'd104     :   lut_data <= 24'h6C1B98 ; 
			9'd105     :   lut_data <= 24'h6C1C59 ; 
			9'd106     :   lut_data <= 24'h6C1D56 ; 
			9'd107     :   lut_data <= 24'h6C1E85 ; 
			9'd108     :   lut_data <= 24'h6C1F28 ; 
			9'd109     :   lut_data <= 24'h6C2029 ; 
			9'd110     :   lut_data <= 24'h6C2152 ; 
			9'd111     :   lut_data <= 24'h6C2257 ; 
			9'd112     :   lut_data <= 24'h6C2300 ; 
			9'd113     :   lut_data <= 24'h6C2400 ; 
			9'd114     :   lut_data <= 24'h6C2500 ; 
			9'd115     :   lut_data <= 24'h6C2601 ; 
			9'd116     :   lut_data <= 24'h6C2701 ; 
			9'd117     :   lut_data <= 24'h6C2801 ; 
			9'd118     :   lut_data <= 24'h6C2901 ; 
			9'd119     :   lut_data <= 24'h6C2A01 ; 
			9'd120     :   lut_data <= 24'h6C2B01 ; 
			9'd121     :   lut_data <= 24'h6C2C01 ; 
			9'd122     :   lut_data <= 24'h6C2D01 ; 
			9'd123     :   lut_data <= 24'h6C2E01 ; 
			9'd124     :   lut_data <= 24'h6C2F01 ; 
			9'd125     :   lut_data <= 24'h6C3001 ; 
			9'd126     :   lut_data <= 24'h6C3101 ; 
			9'd127     :   lut_data <= 24'h6C3201 ; 
			9'd128     :   lut_data <= 24'h6C3301 ; 
			9'd129     :   lut_data <= 24'h6C3401 ; 
			9'd130     :   lut_data <= 24'h6C3501 ; 
			9'd131     :   lut_data <= 24'h6C368C ; 
			9'd132     :   lut_data <= 24'h6C370A ; 
			9'd133     :   lut_data <= 24'h6C38D0 ; 
			9'd134     :   lut_data <= 24'h6C398A ; 
			9'd135     :   lut_data <= 24'h6C3A20 ; 
			9'd136     :   lut_data <= 24'h6C3BE0 ; 
			9'd137     :   lut_data <= 24'h6C3C2D ; 
			9'd138     :   lut_data <= 24'h6C3D10 ; 
			9'd139     :   lut_data <= 24'h6C3E10 ; 
			9'd140     :   lut_data <= 24'h6C3F3E ; 
			9'd141     :   lut_data <= 24'h6C4096 ; 
			9'd142     :   lut_data <= 24'h6C4100 ; 
			9'd143     :   lut_data <= 24'h6C4281 ; 
			9'd144     :   lut_data <= 24'h6C4360 ; 
			9'd145     :   lut_data <= 24'h6C4400 ; 
			9'd146     :   lut_data <= 24'h6C4500 ; 
			9'd147     :   lut_data <= 24'h6C4600 ; 
			9'd148     :   lut_data <= 24'h6C4718 ; 
			9'd149     :   lut_data <= 24'h6C4801 ; 
			9'd150     :   lut_data <= 24'h6C491D ; 
			9'd151     :   lut_data <= 24'h6C4A80 ; 
			9'd152     :   lut_data <= 24'h6C4B18 ; 
			9'd153     :   lut_data <= 24'h6C4C71 ; 
			9'd154     :   lut_data <= 24'h6C4D1C ; 
			9'd155     :   lut_data <= 24'h6C4E16 ; 
			9'd156     :   lut_data <= 24'h6C4F20 ; 
			9'd157     :   lut_data <= 24'h6C5058 ; 
			9'd158     :   lut_data <= 24'h6C512C ; 
			9'd159     :   lut_data <= 24'h6C5225 ; 
			9'd160     :   lut_data <= 24'h6C5300 ; 
			9'd161     :   lut_data <= 24'h6C5481 ; 
			9'd162     :   lut_data <= 24'h6C5549 ; 
			9'd163     :   lut_data <= 24'h6C5600 ; 
			9'd164     :   lut_data <= 24'h6C5700 ; 
			9'd165     :   lut_data <= 24'h6C5800 ; 
			9'd166     :   lut_data <= 24'h6C599E ; 
			9'd167     :   lut_data <= 24'h6C5A00 ; 
			9'd168     :   lut_data <= 24'h6C5B00 ; 
			9'd169     :   lut_data <= 24'h6C5C00 ; 
			9'd170     :   lut_data <= 24'h6C5DFC ; 
			9'd171     :   lut_data <= 24'h6C5E00 ; 
			9'd172     :   lut_data <= 24'h6C5F56 ; 
			9'd173     :   lut_data <= 24'h6C6041 ; 
			9'd174     :   lut_data <= 24'h6C612D ; 
			9'd175     :   lut_data <= 24'h6C6231 ; 
			9'd176     :   lut_data <= 24'h6C6338 ; 
			9'd177     :   lut_data <= 24'h6C6430 ; 
			9'd178     :   lut_data <= 24'h6C6539 ; 
			9'd179     :   lut_data <= 24'h6C6641 ; 
			9'd180     :   lut_data <= 24'h6C670A ; 
			9'd181     :   lut_data <= 24'h6C6820 ; 
			9'd182     :   lut_data <= 24'h6C6920 ; 
			9'd183     :   lut_data <= 24'h6C6A20 ; 
			9'd184     :   lut_data <= 24'h6C6B20 ; 
			9'd185     :   lut_data <= 24'h6C6C00 ; 
			9'd186     :   lut_data <= 24'h6C6D00 ; 
			9'd187     :   lut_data <= 24'h6C6E00 ; 
			9'd188     :   lut_data <= 24'h6C6FFD ; 
			9'd189     :   lut_data <= 24'h6C7000 ; 
			9'd190     :   lut_data <= 24'h6C7117 ; 
			9'd191     :   lut_data <= 24'h6C723D ; 
			9'd192     :   lut_data <= 24'h6C730D ; 
			9'd193     :   lut_data <= 24'h6C742E ; 
			9'd194     :   lut_data <= 24'h6C7511 ; 
			9'd195     :   lut_data <= 24'h6C7600 ; 
			9'd196     :   lut_data <= 24'h6C770A ; 
			9'd197     :   lut_data <= 24'h6C7820 ; 
			9'd198     :   lut_data <= 24'h6C7920 ; 
			9'd199     :   lut_data <= 24'h6C7A20 ; 
			9'd200     :   lut_data <= 24'h6C7B20 ; 
			9'd201     :   lut_data <= 24'h6C7C20 ; 
			9'd202     :   lut_data <= 24'h6C7D20 ; 
			9'd203     :   lut_data <= 24'h6C7E01 ; 
			9'd204     :   lut_data <= 24'h6C7F1C ; 
			9'd205     :   lut_data <= 24'h6C8002 ; 
			9'd206     :   lut_data <= 24'h6C8103 ; 
			9'd207     :   lut_data <= 24'h6C8234 ; 
			9'd208     :   lut_data <= 24'h6C8371 ; 
			9'd209     :   lut_data <= 24'h6C844D ; 
			9'd210     :   lut_data <= 24'h6C8582 ; 
			9'd211     :   lut_data <= 24'h6C8605 ; 
			9'd212     :   lut_data <= 24'h6C8704 ; 
			9'd213     :   lut_data <= 24'h6C8801 ; 
			9'd214     :   lut_data <= 24'h6C8910 ; 
			9'd215     :   lut_data <= 24'h6C8A11 ; 
			9'd216     :   lut_data <= 24'h6C8B14 ; 
			9'd217     :   lut_data <= 24'h6C8C13 ; 
			9'd218     :   lut_data <= 24'h6C8D1F ; 
			9'd219     :   lut_data <= 24'h6C8E06 ; 
			9'd220     :   lut_data <= 24'h6C8F15 ; 
			9'd221     :   lut_data <= 24'h6C9003 ; 
			9'd222     :   lut_data <= 24'h6C9112 ; 
			9'd223     :   lut_data <= 24'h6C9235 ; 
			9'd224     :   lut_data <= 24'h6C930F ; 
			9'd225     :   lut_data <= 24'h6C947F ; 
			9'd226     :   lut_data <= 24'h6C9507 ; 
			9'd227     :   lut_data <= 24'h6C9617 ; 
			9'd228     :   lut_data <= 24'h6C971F ; 
			9'd229     :   lut_data <= 24'h6C9838 ; 
			9'd230     :   lut_data <= 24'h6C991F ; 
			9'd231     :   lut_data <= 24'h6C9A07 ; 
			9'd232     :   lut_data <= 24'h6C9B30 ; 
			9'd233     :   lut_data <= 24'h6C9C2F ; 
			9'd234     :   lut_data <= 24'h6C9D07 ; 
			9'd235     :   lut_data <= 24'h6C9E72 ; 
			9'd236     :   lut_data <= 24'h6C9F3F ; 
			9'd237     :   lut_data <= 24'h6CA07F ; 
			9'd238     :   lut_data <= 24'h6CA172 ; 
			9'd239     :   lut_data <= 24'h6CA257 ; 
			9'd240     :   lut_data <= 24'h6CA37F ; 
			9'd241     :   lut_data <= 24'h6CA400 ; 
			9'd242     :   lut_data <= 24'h6CA537 ; 
			9'd243     :   lut_data <= 24'h6CA67F ; 
			9'd244     :   lut_data <= 24'h6CA772 ; 
			9'd245     :   lut_data <= 24'h6CA883 ; 
			9'd246     :   lut_data <= 24'h6CA94F ; 
			9'd247     :   lut_data <= 24'h6CAA00 ; 
			9'd248     :   lut_data <= 24'h6CAB00 ; 
			9'd249     :   lut_data <= 24'h6CAC67 ; 
			9'd250     :   lut_data <= 24'h6CAD03 ; 
			9'd251     :   lut_data <= 24'h6CAE0C ; 
			9'd252     :   lut_data <= 24'h6CAF00 ; 
			9'd253     :   lut_data <= 24'h6CB010 ; 
			9'd254     :   lut_data <= 24'h6CB100 ; 
			9'd255     :   lut_data <= 24'h6CB288 ; 
			9'd256     :   lut_data <= 24'h6CB32D ; 
			9'd257     :   lut_data <= 24'h6CB400 ; 
			9'd258     :   lut_data <= 24'h6CB500 ; 
			9'd259     :   lut_data <= 24'h6CB600 ; 
			9'd260     :   lut_data <= 24'h6CB7FF ; 
			9'd261     :   lut_data <= 24'h6CB800 ; 
			9'd262     :   lut_data <= 24'h6CB90A ; 
			9'd263     :   lut_data <= 24'h6CBA20 ; 
			9'd264     :   lut_data <= 24'h6CBB20 ; 
			9'd265     :   lut_data <= 24'h6CBC20 ; 
			9'd266     :   lut_data <= 24'h6CBD20 ; 
			9'd267     :   lut_data <= 24'h6CBE20 ; 
			9'd268     :   lut_data <= 24'h6CBF20 ; 
			9'd269     :   lut_data <= 24'h6CC020 ; 
			9'd270     :   lut_data <= 24'h6CC120 ; 
			9'd271     :   lut_data <= 24'h6CC220 ; 
			9'd272     :   lut_data <= 24'h6CC320 ; 
			9'd273     :   lut_data <= 24'h6CC420 ; 
			9'd274     :   lut_data <= 24'h6CC520 ; 
			9'd275     :   lut_data <= 24'h6CC600 ; 
			9'd276     :   lut_data <= 24'h6CC700 ; 
			9'd277     :   lut_data <= 24'h6CC800 ; 
			9'd278     :   lut_data <= 24'h6CC9FF ; 
			9'd279     :   lut_data <= 24'h6CCA00 ; 
			9'd280     :   lut_data <= 24'h6CCB0A ; 
			9'd281     :   lut_data <= 24'h6CCC20 ; 
			9'd282     :   lut_data <= 24'h6CCD20 ; 
			9'd283     :   lut_data <= 24'h6CCE20 ; 
			9'd284     :   lut_data <= 24'h6CCF20 ; 
			9'd285     :   lut_data <= 24'h6CD020 ; 
			9'd286     :   lut_data <= 24'h6CD120 ; 
			9'd287     :   lut_data <= 24'h6CD220 ; 
			9'd288     :   lut_data <= 24'h6CD320 ; 
			9'd289     :   lut_data <= 24'h6CD420 ; 
			9'd290     :   lut_data <= 24'h6CD520 ; 
			9'd291     :   lut_data <= 24'h6CD620 ; 
			9'd292     :   lut_data <= 24'h6CD720 ; 
			9'd293     :   lut_data <= 24'h6CD800 ; 
			9'd294     :   lut_data <= 24'h6CD900 ; 
			9'd295     :   lut_data <= 24'h6CDA00 ; 
			9'd296     :   lut_data <= 24'h6CDBFF ; 
			9'd297     :   lut_data <= 24'h6CDC00 ; 
			9'd298     :   lut_data <= 24'h6CDD0A ; 
			9'd299     :   lut_data <= 24'h6CDE20 ; 
			9'd300     :   lut_data <= 24'h6CDF20 ; 
			9'd301     :   lut_data <= 24'h6CE020 ; 
			9'd302     :   lut_data <= 24'h6CE120 ; 
			9'd303     :   lut_data <= 24'h6CE220 ; 
			9'd304     :   lut_data <= 24'h6CE320 ; 
			9'd305     :   lut_data <= 24'h6CE420 ; 
			9'd306     :   lut_data <= 24'h6CE520 ; 
			9'd307     :   lut_data <= 24'h6CE620 ; 
			9'd308     :   lut_data <= 24'h6CE720 ; 
			9'd309     :   lut_data <= 24'h6CE820 ; 
			9'd310     :   lut_data <= 24'h6CE920 ; 
			9'd311     :   lut_data <= 24'h6CEA00 ; 
			9'd312     :   lut_data <= 24'h6CEB00 ; 
			9'd313     :   lut_data <= 24'h6CEC00 ; 
			9'd314     :   lut_data <= 24'h6CED00 ; 
			9'd315     :   lut_data <= 24'h6CEE00 ; 
			9'd316     :   lut_data <= 24'h6CEF00 ; 
			9'd317     :   lut_data <= 24'h6CF000 ; 
			9'd318     :   lut_data <= 24'h6CF100 ; 
			9'd319     :   lut_data <= 24'h6CF200 ; 
			9'd320     :   lut_data <= 24'h6CF300 ; 
			9'd321     :   lut_data <= 24'h6CF400 ; 
			9'd322     :   lut_data <= 24'h6CF500 ; 
			9'd323     :   lut_data <= 24'h6CF600 ; 
			9'd324     :   lut_data <= 24'h6CF700 ; 
			9'd325     :   lut_data <= 24'h6CF800 ; 
			9'd326     :   lut_data <= 24'h6CF900 ; 
			9'd327     :   lut_data <= 24'h6CFA00 ; 
			9'd328     :   lut_data <= 24'h6CFB00 ; 
			9'd329     :   lut_data <= 24'h6CFC00 ; 
			9'd330     :   lut_data <= 24'h6CFD00 ; 
			9'd331     :   lut_data <= 24'h6CFE00 ; 
			9'd332     :   lut_data <= 24'h6CFFDA ; 
			9'd333     :   lut_data <= 24'h647700 ; //Set the Most Significant Bit of the SPA location to 0
			9'd334     :   lut_data <= 24'h645220 ; //Set the SPA for port B.
			9'd335     :   lut_data <= 24'h645300 ; //Set the SPA for port B.
			9'd336     :   lut_data <= 24'h64709E ; //Set the Least Significant Byte of the SPA location
			9'd337     :   lut_data <= 24'h647403 ; //Enable the Internal EDID for Ports
			9'd338     :   lut_data <= 24'h980002 ; //Enable the Internal EDID for Ports
			9'd339     :   lut_data <= 24'h44C92c ; //Enable the Internal EDID for Ports
			9'd340     :   lut_data <= 24'h721470 ; //Enable the Internal EDID for Ports
			9'd341     :   lut_data <= 24'h729ae0 ; //Enable the Internal EDID for Ports
			9'd342     :   lut_data <= 24'hFFFFFF ; //Enable the Internal EDID for Ports 
            default:begin
                lut_data  <=  'hFFFFFF ; //Nbr of times to search for good phase
            end
        endcase
    end
    else if(cfg_done==1'b1)begin
                lut_data  <=  'hFFFFFF ; //Nbr of times to search for good phase
    end
end

//按照设备地址，寄存器地址和写入的数据的顺序，赋值
assign {dev_addr,mem_addr,wr_data} = lut_data;

//--------------------wr_index--------------------
always @(posedge clk)begin
    if(rst == 1'b1)begin
        wr_index <= 'd0;//写寄存器索引
    end
    else if(cfg_done)begin//配置寄存器全部完成后保持位0
        wr_index <= 'd0;
    end
    else if(wr_done && cfg_done==1'b0) begin//配置寄存器未完成，并且接收到写响应
        wr_index <= wr_index + 1'b1;
    end
    else if(done)begin
    	wr_index <= wr_index + 1'b1;
    end
    else begin
        wr_index <= wr_index;
    end
end

//--------------------rd_index--------------------
always @(posedge clk)begin
    if(rst == 1'b1)begin
        rd_index <= 'd0;//读寄存器索引
    end
    else if(dev_addr==8'hff)begin//读到最后一个寄存器，索引值保持不变
        rd_index <= rd_index;
    end
    else if(rd_done && cfg_done==1'b1) begin//接收到读响应，索引值加一
        rd_index <= rd_index + 1'b1;
    end
    else begin
        rd_index <= rd_index;
    end
end

//--------------------wr_req--------------------
always @(posedge clk)begin
    if(rst == 1'b1)begin
        wr_req <= 1'b0;
    end
    else if(cfg_done==1'b1)begin//接收到写响应时，写请求变低
        wr_req <= 1'b0;
    end
    else if(wr_done)begin//接收到写响应时，写请求变低
        wr_req <= 1'b0;
    end
    else if(state==WR_CHECK && cfg_done==1'b0 && ready && dev_addr!=8'hff)begin//配置寄存器还没有全部完成，在WR_CHECK状态下产生写请求
        wr_req <= 1'b1;
    end
    else begin
        wr_req <= wr_req;
    end
end

//--------------------rd_req--------------------
always @(posedge clk)begin
    if(rst == 1'b1)begin
        rd_req <= 1'b0;
    end
    else if(dev_addr==8'hff && state==WR_CHECK)begin//读取配置完成
        rd_req <= 1'b0;
    end
    else if(rd_done)begin//接收到读响应，读请求取消
        rd_req <= 1'b0;
    end
    else if(cfg_done && ready && state==WR_CHECK && dev_addr!=8'hff)begin//在WR_CHECK状态下，检测到配置完成，产生读请求
        rd_req <= 1'b1;
    end
    else begin
        rd_req <= rd_req;
    end
end

//--------------------cfg_done--------------------
always @(posedge clk)begin
    if(rst == 1'b1)begin
        cfg_done <= 1'b0;//配置寄存器结束标志
    end
    else if(dev_addr ==8'hff)begin
        cfg_done <= 1'b1;
    end
end

//--------------------start--------------------
always @(posedge clk)begin
    if(rst == 1'b1)begin
        start <= 1'b0;//配置寄存器结束标志
    end
    else if(state==WR_CHECK && cfg_done==1'b0 && ready && dev_addr!=8'hff)begin//写开始
        start <= 1'b1;
    end
    else if(cfg_done==1'b1 && ready && state==WR_CHECK && dev_addr!=8'hff)begin//读开始
        start <= 1'b1;
    end
    else begin
    	start <= 1'b0;
    end
end
    
	i2c_driver inst_i2c_driver (
			.clk      (clk),
			.rst      (rst),
			.wr_req   (wr_req),
			.rd_req   (rd_req),
			.start    (start),
			.dev_addr (dev_addr),
			.mem_addr (mem_addr),
			.wr_data  (wr_data),
			.rd_data  (rd_data),
			.rd_done  (rd_done),
			.wr_done  (wr_done),
            .err_flag (err_flag),
			.scl      (scl),
			.sda      (sda)
		);
endmodule

