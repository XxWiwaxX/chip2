/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

/*
 * 8-bit RISC-V-Lite CPU
 * Supports: ADD, ADDI, SUB, MUL, LW, SW, BEQ, BNE
 * Memory: 32 Bytes internal RAM
 */

`default_nettype none

module tt_um_wscore (
    input  wire [7:0] ui_in,    // Data Input (for loading/external bus)
    output wire [7:0] uo_out,   // Data Output / ALU Result
    input  wire [7:0] uio_in,   // Address/Control bits
    output wire [7:0] uio_out,  // External Address Bus
    output wire [7:0] uio_oe,   // IO Enable (configured as output for Address)
    input  wire       ena,      
    input  wire       clk,      
    input  wire       rst_n     
);

    // --- CPU Registers ---
    reg [7:0] pc;
    reg [15:0] ir;              // Instruction Register
    reg [7:0] regs [7:0];       // 8 Registers (8-bit)
    reg [7:0] ram  [31:0];      // 32 Bytes RAM
    reg [2:0] state;

    // FSM States
    localparam LOAD   = 3'd0;   // Bootloader mode
    localparam FETCH  = 3'd1;
    localparam DECODE = 3'd2;
    localparam EXEC   = 3'd3;
    localparam MEM    = 3'd4;   // Memory Access (LW/SW)

    // Opcode definitions (Simplified RISC-V style)
    localparam OP_ADD  = 4'b0000;
    localparam OP_ADDI = 4'b0001;
    localparam OP_MUL  = 4'b0010;
    localparam OP_LW   = 4'b0011;
    localparam OP_SW   = 4'b0100;
    localparam OP_BEQ  = 4'b0101;
    localparam OP_BNE  = 4'b0110;

    // --- Hardware Multiplier ---
    wire [7:0] rs1_val = regs[ir[6:4]];
    wire [7:0] rs2_val = regs[ir[2:0]];
    wire [15:0] mul_out = rs1_val * rs2_val;

    // Bus Wiring
    assign uio_out = pc;        // Address bus shows current PC
    assign uio_oe  = 8'hFF;     // Set UIO to output for address
    assign uo_out  = regs[ir[9:7]]; // Output value of 'rd' for monitoring

    integer i;

    always @(posedge clk) begin
        if (!rst_n) begin
            pc <= 0;
            state <= LOAD;
            for (i = 0; i < 8; i = i + 1) regs[i] <= 8'h0;
        end else if (ena) begin
            case (state)
                // --- Initial Load Mechanism ---
                // While in LOAD, ui_in writes to ram[uio_in]. 
                // Pull uio_in[7] HIGH to exit LOAD mode and start CPU.
                LOAD: begin
                    if (uio_in[7]) state <= FETCH;
                    else ram[uio_in[4:0]] <= ui_in;
                end

                FETCH: begin
                    // Instructions are 2 bytes (16-bit)
                    ir <= {ram[pc+1], ram[pc]};
                    state <= DECODE;
                end

                DECODE: begin
                    state <= EXEC;
                end

                EXEC: begin
                    case (ir[15:12])
                        OP_ADD:  if (ir[9:7] != 0) regs[ir[9:7]] <= regs[ir[6:4]] + regs[ir[2:0]];
                        OP_ADDI: if (ir[9:7] != 0) regs[ir[9:7]] <= regs[ir[6:4]] + ir[3:0];
                        OP_MUL:  if (ir[9:7] != 0) regs[ir[9:7]] <= mul_out[7:0];
                        
                        OP_BEQ: begin
                            if (regs[ir[9:7]] == regs[ir[6:4]]) pc <= pc + ir[3:0];
                            else pc <= pc + 2;
                        end

                        OP_BNE: begin
                            if (regs[ir[9:7]] != regs[ir[6:4]]) pc <= pc + ir[3:0];
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
                    if (ir[15:12] == OP_LW && ir[9:7] != 0)
                        regs[ir[9:7]] <= ram[regs[ir[6:4]][4:0]];
                    else if (ir[15:12] == OP_SW)
                        ram[regs[ir[6:4]][4:0]] <= regs[ir[9:7]];
                    
                    pc <= pc + 2;
                    state <= FETCH;
                end
            endcase
        end
    end

    // Force r0 to 0
    always @(*) regs[0] = 8'h0;

endmodule
