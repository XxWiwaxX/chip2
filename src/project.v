/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

/*
 * 8-bit RISC-V-Lite CPU
 * Supports: ADD, ADDI, SUB, MUL, LW, SW, BEQ, BNE
 * Memory: 32 Bytes internal RAM
 */

/*
 * 8-bit RISC-V-Lite CPU
 * Supports: ADD, ADDI, SUB, MUL, LW, SW, BEQ, BNE
 * Memory: 24 Bytes internal RAM (Reduced for density)
 */

`default_nettype none

module tt_um_example (
    input  wire [7:0] ui_in,    
    output wire [7:0] uo_out,   
    input  wire [7:0] uio_in,   
    output wire [7:0] uio_out,  
    output wire [7:0] uio_oe,   
    input  wire       ena,      
    input  wire       clk,      
    input  wire       rst_n     
);

    // --- CPU Internal State ---
    reg [7:0] pc;
    reg [15:0] ir;              
    reg [7:0] regs [7:1];       // r1-r7 (r0 is hardwired 0)
    reg [7:0] ram  [23:0];      // Reduced to 24 Bytes RAM
    reg [2:0] state;

    // FSM States
    localparam LOAD   = 3'd0;   
    localparam FETCH  = 3'd1;
    localparam DECODE = 3'd2;
    localparam EXEC   = 3'd3;
    localparam MEM    = 3'd4;   

    // Opcode definitions
    localparam OP_ADD  = 4'b0000;
    localparam OP_ADDI = 4'b0001;
    localparam OP_MUL  = 4'b0010;
    localparam OP_LW   = 4'b0011;
    localparam OP_SW   = 4'b0100;
    localparam OP_BEQ  = 4'b0101;
    localparam OP_BNE  = 4'b0110;

    // --- Operand Selection Logic ---
    // Handle r0 as 0 automatically
    wire [7:0] rs1_idx = ir[6:4];
    wire [7:0] rs2_idx = ir[2:0];
    wire [7:0] rd_idx  = ir[9:7];

    wire [7:0] rs1_val = (rs1_idx == 0) ? 8'h00 : regs[rs1_idx];
    wire [7:0] rs2_val = (rs2_idx == 0) ? 8'h00 : regs[rs2_idx];
    wire [7:0] rd_val  = (rd_idx == 0)  ? 8'h00 : regs[rd_idx];

    // Hardware Multiplier
    wire [15:0] mul_out = rs1_val * rs2_val;

    // External Bus Assignments
    assign uio_out = pc;        
    assign uio_oe  = 8'hFF;     
    assign uo_out  = rd_val;    // Monitor current rd value

    integer i;

    always @(posedge clk) begin
        if (!rst_n) begin
            pc <= 0;
            state <= LOAD;
            for (i = 1; i < 8; i = i + 1) regs[i] <= 8'h00;
        end else if (ena) begin
            case (state)
                LOAD: begin
                    if (uio_in[7]) state <= FETCH;
                    else if (uio_in[4:0] < 24) // Bounds check for 24 bytes
                        ram[uio_in[4:0]] <= ui_in;
                end

                FETCH: begin
                    ir <= {ram[pc+1], ram[pc]};
                    state <= DECODE;
                end

                DECODE: state <= EXEC;

                EXEC: begin
                    case (ir[15:12])
                        OP_ADD:  if (rd_idx != 0) regs[rd_idx] <= rs1_val + rs2_val;
                        OP_ADDI: if (rd_idx != 0) regs[rd_idx] <= rs1_val + ir[3:0];
                        OP_MUL:  if (rd_idx != 0) regs[rd_idx] <= mul_out[7:0];
                        
                        OP_BEQ: begin
                            if (rd_val == rs1_val) pc <= pc + ir[3:0];
                            else pc <= pc + 2;
                        end

                        OP_BNE: begin
                            if (rd_val != rs1_val) pc <= pc + ir[3:0];
                            else pc <= pc + 2;
                        end

                        OP_LW, OP_SW: state <= MEM;
                        default: pc <= pc + 2;
                    endcase
                    
                    if (ir[15:12] != OP_BEQ && ir[15:12] != OP_BNE && ir[15:12] != OP_LW && ir[15:12] != OP_SW)
                        pc <= pc + 2;
                    
                    if (state != MEM) state <= FETCH;
                end

                MEM: begin
                    if (ir[15:12] == OP_LW && rd_idx != 0)
                        regs[rd_idx] <= (rs1_val < 24) ? ram[rs1_val[4:0]] : 8'h00;
                    else if (ir[15:12] == OP_SW)
                        if (rs1_val < 24) ram[rs1_val[4:0]] <= rd_val;
                    
                    pc <= pc + 2;
                    state <= FETCH;
                end
            endcase
        end
    end

    wire _unused = &{uio_in[6:5]};

endmodule
