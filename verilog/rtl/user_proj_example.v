// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

`default_nettype none
/*
 *-------------------------------------------------------------
 *
 * user_proj_example
 *
 * This is an example of a (trivially simple) user project,
 * showing how the user project can connect to the logic
 * analyzer, the wishbone bus, and the I/O pads.
 *
 * This project generates an integer count, which is output
 * on the user area GPIO pads (digital output only).  The
 * wishbone connection allows the project to be controlled
 * (start and stop) from the management SoC program.
 *
 * See the testbenches in directory "mprj_counter" for the
 * example programs that drive this user project.  The three
 * testbenches are "io_ports", "la_test1", and "la_test2".
 *
 *-------------------------------------------------------------
 */

module user_proj_example #(
    parameter BITS = 32
)(
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif

    // Wishbone Slave ports (WB MI A)
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [3:0] wbs_sel_i,
    input [31:0] wbs_dat_i,
    input [31:0] wbs_adr_i,
    output wbs_ack_o,
    output [31:0] wbs_dat_o,

    // Logic Analyzer Signals
    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oenb,

    // IOs
    input  [`MPRJ_IO_PADS-1:0] io_in,
    output [`MPRJ_IO_PADS-1:0] io_out,
    output [`MPRJ_IO_PADS-1:0] io_oeb,

    // IRQ
    output [2:0] irq
);
    wire clk;
    wire rst_n;
    wire [2:0] light_highway;
    wire [2:0] light_farm;
    wire C;

    wire [`MPRJ_IO_PADS-1:0] io_in;
    wire [`MPRJ_IO_PADS-1:0] io_out;
    wire [`MPRJ_IO_PADS-1:0] io_oeb;
	
    /*wire clk;
    wire rst;

    wire [`MPRJ_IO_PADS-1:0] io_in;
    wire [`MPRJ_IO_PADS-1:0] io_out;
    wire [`MPRJ_IO_PADS-1:0] io_oeb;

    wire [31:0] rdata; 
    wire [31:0] wdata;
    wire [BITS-1:0] count;

    wire valid;
    wire [3:0] wstrb;
    wire [31:0] la_write;

    // WB MI A
    assign valid = wbs_cyc_i && wbs_stb_i; 
    assign wstrb = wbs_sel_i & {4{wbs_we_i}};
    assign wbs_dat_o = rdata;
    assign wdata = wbs_dat_i;*/

    // IO
    assign io_out[35:33] = light_highway;
    assign io_out[32:30] = light_farm;
    assign io_oeb = 0;
    assign clk = wb_clk_i;
    assign rst_n = wb_rst_i;
    assign C = io_in[`MPRJ_IO_PADS-9]; 
    //assign io_out = count;
    //assign io_oeb = {(`MPRJ_IO_PADS-1){rst}};

    // IRQ
    assign irq = 3'b000;	// Unused

    // LA
   /* assign la_data_out = {{(127-BITS){1'b0}}, count};
    // Assuming LA probes [63:32] are for controlling the count register  
    assign la_write = ~la_oenb[63:32] & ~{BITS{valid}};
    // Assuming LA probes [65:64] are for controlling the count clk & reset  
    assign clk = (~la_oenb[64]) ? la_data_in[64]: wb_clk_i;
    assign rst = (~la_oenb[65]) ? la_data_in[65]: wb_rst_i;

    counter #(
        .BITS(BITS)
    ) counter(
        .clk(clk),
        .reset(rst),
        .ready(wbs_ack_o),
        .valid(valid),
        .rdata(rdata),
        .wdata(wbs_dat_i),
        .wstrb(wstrb),
        .la_write(la_write),
        .la_input(la_data_in[63:32]),
        .count(count)
    );*/
    
    iiitb_tlc dut(light_highway, light_farm, C, clk, rst_n);
    
endmodule

module iiitb_tlc(light_highway, light_farm, C, clk, rst_n);

	parameter HGRE_FRED = 2'b00, // Highway green and farm red
		  HYEL_FRED = 2'b01,// Highway yellow and farm red
		  HRED_FGRE = 2'b10,// Highway red and farm green
		  HRED_FYEL = 2'b11;// Highway red and farm yellow
	input C, // sensor
   	clk, // clock = 50 MHz
   	rst_n; // reset active low

	output reg[2:0] light_highway, light_farm; // output of lights
	reg[1:0]  RED_count_en, YELLOW_count_en1, YELLOW_count_en2;
	reg[1:0] state, next_state;
	integer i;
// next state
	always @(posedge clk or negedge rst_n)
		begin
			if(~rst_n)
			begin
			RED_count_en<=0;YELLOW_count_en1<=0;YELLOW_count_en2<=0;
			 state <= 2'b00;
			end
			else 
			 state <= next_state; 
		end
// FSM
	always @(*)
		begin
			case(state)
				HGRE_FRED: 
					begin // Green on highway and red on farm way

					 RED_count_en <= 2'b01;
					 YELLOW_count_en1 <= 2'b00;
					 YELLOW_count_en2 <= 2'b00;
					 light_highway <= 3'b001;
					 light_farm <= 3'b100;
					 if(C) next_state <= HYEL_FRED; 
					 // if sensor detects vehicles on farm road, 

					 else next_state <= HGRE_FRED;
					end
				HYEL_FRED: 
					begin// yellow on highway and red on farm way

					RED_count_en <= 2'b00;
					YELLOW_count_en1 <= 2'b01;
					YELLOW_count_en2 <= 2'b00;					  
					light_highway <= 3'b010;
					light_farm <= 3'b100;
					next_state <= HRED_FGRE;

					end
				HRED_FGRE: 
					begin// red on highway and green on farm way
					
					RED_count_en <= 2'b01;
					YELLOW_count_en1 <= 2'b00;
					YELLOW_count_en2 <= 2'b00;					 
					light_highway <= 3'b100;
					light_farm <= 3'b001; 
					next_state <= HRED_FYEL;

					end
				HRED_FYEL:
					begin// red on highway and yellow on farm way

					RED_count_en <= 2'b00;
					YELLOW_count_en1 <= 2'b00;
					YELLOW_count_en2 <= 2'b01;					 
					light_highway <= 3'b100;
					light_farm <= 3'b010; 
					next_state <= HGRE_FRED;

					end
				default: next_state <= HGRE_FRED;
			endcase
		end

endmodule

/*module counter #(
    parameter BITS = 32
)(
    input clk,
    input reset,
    input valid,
    input [3:0] wstrb,
    input [BITS-1:0] wdata,
    input [BITS-1:0] la_write,
    input [BITS-1:0] la_input,
    output ready,
    output [BITS-1:0] rdata,
    output [BITS-1:0] count
);
    reg ready;
    reg [BITS-1:0] count;
    reg [BITS-1:0] rdata;

    always @(posedge clk) begin
        if (reset) begin
            count <= 0;
            ready <= 0;
        end else begin
            ready <= 1'b0;
            if (~|la_write) begin
                count <= count + 1;
            end
            if (valid && !ready) begin
                ready <= 1'b1;
                rdata <= count;
                if (wstrb[0]) count[7:0]   <= wdata[7:0];
                if (wstrb[1]) count[15:8]  <= wdata[15:8];
                if (wstrb[2]) count[23:16] <= wdata[23:16];
                if (wstrb[3]) count[31:24] <= wdata[31:24];
            end else if (|la_write) begin
                count <= la_write & la_input;
            end
        end
    end

endmodule*/

`default_nettype wire
