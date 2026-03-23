# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

async def load_program(dut, program):
    """
    Helper function to load bytes into the CPU RAM via the external bus.
    uio_in[7] = 0 (Load Mode)
    uio_in[4:0] = Address
    ui_in = Data Byte
    """
    dut._log.info("Starting bootloader...")
    for addr, data in enumerate(program):
        dut.uio_in.value = addr  # Set address (bit 7 is 0)
        dut.ui_in.value = data   # Set data
        await RisingEdge(dut.clk)
    
    # Start Execution Mode
    dut.uio_in.value = 0x80 # Set bit 7 HIGH to exit LOAD state
    await RisingEdge(dut.clk)
    dut._log.info("Program loaded. Switching to EXEC mode.")

@cocotb.test()
async def test_cpu_multiplier_and_logic(dut):
    # Start the clock (10MHz)
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset the design
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await Timer(20, units="us")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Format: [Opcode(4)][Unused(2)][rd(3)][rs1(3)][imm/rs2(4)]
    
    # 1. ADDI r1, r0, 5  -> 0001 00 001 000 0101 -> 0x1085
    # 2. ADDI r2, r0, 4  -> 0001 00 010 000 0100 -> 0x1104
    # 3. MUL  r3, r1, r2 -> 0010 00 011 001 0010 -> 0x2192
    # 4. SW   r3, r0     -> 0100 00 011 000 0000 -> 0x4180
    
    program = [
        0x85, 0x10, # ADDI r1, r0, 5 (Little Endian: 0x1085)
        0x04, 0x11, # ADDI r2, r0, 4 (Little Endian: 0x1104)
        0x92, 0x21, # MUL  r3, r1, r2 (Little Endian: 0x2192)
        0x80, 0x41  # SW   r3, r0     (Little Endian: 0x4180)
    ]

    await load_program(dut, program)

    # Run for enough cycles to complete Fetch/Decode/Exec/Mem cycles
    # Each instruction takes ~3-4 cycles
    for _ in range(30):
        await RisingEdge(dut.clk)
        # uo_out is wired to output 'rd' for debugging
        dut._log.info(f"PC: {dut.uio_out.value} | ALU Out: {dut.uo_out.value}")

    # Final Check: r3 should contain 20 (0x14)
    # Based on the Verilog, uo_out shows the last rd written.
    assert int(dut.uo_out.value) == 20
    dut._log.info("Test Passed: 5 * 4 = 20 successfully calculated and stored.")
