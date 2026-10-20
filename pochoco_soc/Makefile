# Copyright 2026 Universidad de los Andes.
# Licensed under the Solderpad Hardware License, Version 0.51 (the "License");
# you may not use this file except in compliance with the License.
# SPDX-License-Identifier: SHL-0.51
#
# Course: Arquitectura de Computadores (2026)
#
# Authors:
# - Nicolás Villegas <navillegas@miuandes.cl>

# ============================================================
# Configuration
# ============================================================

TOP := game_top
PCF := goboard.pcf

# ============================================================
# Assembly Configuration
# ============================================================

ASM := assembler_v1.py
GAME_ASM := sw/game.s
HEX := sw/game.hex

# ============================================================
# RTL Sources
# ============================================================

SRC := $(wildcard ./rtl/*.v ./rtl/**/*.v)

# ============================================================
# Build Targets
# ============================================================

JSON := $(TOP).json
ASC := $(TOP).asc
BIN := $(TOP).bin

.PHONY: all prog clean stats

# ============================================================
# Default Target
# ============================================================

all: prog

# ============================================================
# Step 0: Generate game.hex from Assembly
# ============================================================

$(HEX): $(GAME_ASM) $(ASM)
	python3 $(ASM) $(GAME_ASM) $(HEX)

# ============================================================
# Step 1: Synthesis using Yosys
# ============================================================

$(JSON): $(SRC) $(HEX)
	yosys -p "read_verilog $(SRC); synth_ice40 -top $(TOP) -json $(JSON); stat"

# ============================================================
# Step 2: Place and Route using NextPNR
# ============================================================

$(ASC): $(JSON) $(PCF)
	nextpnr-ice40 --hx1k --package vq100 --freq 25 --json $(JSON) --pcf $(PCF) --asc $(ASC)

# ============================================================
# Step 3: Bitstream Generation
# ============================================================

$(BIN): $(ASC)
	icepack $(ASC) $(BIN)

# ============================================================
# Step 4: Flash the Board
# ============================================================

prog: $(BIN)
	iceprog $(BIN)

# ============================================================
# Clean up generated files
# ============================================================

clean:
	rm -f $(JSON) $(ASC) $(BIN)