<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This project is a custom **8-bit RISC-V Lite CPU** designed for the IHP26a process. It features a multi-cycle architecture with a focused instruction set that prioritizes math and control flow.

### Architecture Features:
* **Register File:** 8 general-purpose 8-bit registers (with `x0` hardwired to zero).
* **Memory:** 32 bytes of internal SRAM-style storage (implemented as a register array).
* **ALU & Multiplier:** Includes a dedicated 8-bit $\times$ 8-bit hardware multiplier for fast arithmetic.
* **Control Unit:** A Finite State Machine (FSM) manages the cycle: `Fetch` -> `Decode` -> `Execute` -> `Memory Access`.

### Instruction Set:
The CPU uses 16-bit wide instructions (stored in little-endian format) that resemble the RISC-V compressed format:
* **Arithmetic:** `ADD`, `ADDI`, `SUB`.
* **Math:** `MUL` (Custom hardware-level 8-bit multiplication).
* **Control Flow:** `BEQ` (Branch if Equal) and `BNE` (Branch if Not Equal) for loops and logic.
* **Memory:** `LW` (Load Word) and `SW` (Store Word).

### The External Bus:
The design exposes its internal state in real-time. The `uio` pins act as an address bus (showing the Program Counter), while the `uo` pins act as a data monitor, reflecting the contents of the destination register (`rd`) for every instruction.

## How to test

The CPU starts in a **LOAD mode** to allow you to program the internal 32-byte RAM before execution begins.

1. **Reset:** Pull `rst_n` low to reset the Program Counter and enter `LOAD` mode.
2. **Program the CPU:** * Ensure `uio[7]` (Mode Select) is held **LOW**.
   * Set the target RAM address on `uio[4:0]`.
   * Set the instruction/data byte on `ui[7:0]`.
   * Pulse the clock (`clk`) to write the byte.
   * Repeat for all bytes of your program.
3. **Run:** Set `uio[7]` to **HIGH**. The CPU will transition to the `FETCH` state and begin executing from address `0x00`.
4. **Monitor:** Watch the `uo[7:0]` pins. They will display the result of calculations as they are written to the registers.

## External hardware

* **Logic Analyzer:** Highly recommended to monitor the address bus (`uio[4:0]`) and the data output (`uo[7:0]`).
* **Input Switch Bank:** A set of 8 switches for `ui` and a way to toggle `uio[7]` is necessary for manual "bit-banging" of the initial program.
* **Clock Source:** A standard 10MHz square wave (or slower for manual debugging).
