#!/usr/bin/env python3
"""
Este es el ASSEMBLER V1, por lo que probablemente no lo usemos al final xd
Es para el Espino Core que tiene registros x0 al x15, es info del ppt
Traduce un archivo .s a un archivo .hex (una palabra de 32 bits en
hexadecimal por linea), compatible con el formato usado por el pochoco_soc.

Uso: python3 asm.py entrada.s salida.hex
"""

import sys
import re

"""
---------------------------------------------------------------------
1. Tablas de registros y de instrucciones
---------------------------------------------------------------------
"""

REGISTERS = {f"x{i}": i for i in range(16)}

OPCODE_LOAD   = 0x03
OPCODE_OPIMM  = 0x13
OPCODE_AUIPC  = 0x17
OPCODE_STORE  = 0x23
OPCODE_OP     = 0x33
OPCODE_LUI    = 0x37
OPCODE_BRANCH = 0x63
OPCODE_JALR   = 0x67
OPCODE_JAL    = 0x6f


"Cada entrada describe: (formato, opcode, funct3, funct7_o_None)"

INSTR_TABLE = {
    "add":  ("R", OPCODE_OP, 0b000, 0b0000000),
    "sub":  ("R", OPCODE_OP, 0b000, 0b0100000),
    "sll":  ("R", OPCODE_OP, 0b001, 0b0000000),
    "slt":  ("R", OPCODE_OP, 0b010, 0b0000000),
    "sltu": ("R", OPCODE_OP, 0b011, 0b0000000),
    "xor":  ("R", OPCODE_OP, 0b100, 0b0000000),
    "srl":  ("R", OPCODE_OP, 0b101, 0b0000000),
    "sra":  ("R", OPCODE_OP, 0b101, 0b0100000),
    "or":   ("R", OPCODE_OP, 0b110, 0b0000000),
    "and":  ("R", OPCODE_OP, 0b111, 0b0000000),

    "addi":  ("I", OPCODE_OPIMM, 0b000, None),
    "slti":  ("I", OPCODE_OPIMM, 0b010, None),
    "sltiu": ("I", OPCODE_OPIMM, 0b011, None),
    "xori":  ("I", OPCODE_OPIMM, 0b100, None),
    "ori":   ("I", OPCODE_OPIMM, 0b110, None),
    "andi":  ("I", OPCODE_OPIMM, 0b111, None),
    "slli":  ("SHAMT", OPCODE_OPIMM, 0b001, 0b0000000),
    "srli":  ("SHAMT", OPCODE_OPIMM, 0b101, 0b0000000),
    "srai":  ("SHAMT", OPCODE_OPIMM, 0b101, 0b0100000),

    "lb":  ("ILOAD", OPCODE_LOAD, 0b000, None),
    "lh":  ("ILOAD", OPCODE_LOAD, 0b001, None),
    "lw":  ("ILOAD", OPCODE_LOAD, 0b010, None),
    "lbu": ("ILOAD", OPCODE_LOAD, 0b100, None),
    "lhu": ("ILOAD", OPCODE_LOAD, 0b101, None),
    "jalr": ("ILOAD", OPCODE_JALR, 0b000, None),

    "sb": ("S", OPCODE_STORE, 0b000, None),
    "sh": ("S", OPCODE_STORE, 0b001, None),
    "sw": ("S", OPCODE_STORE, 0b010, None),

    "beq":  ("B", OPCODE_BRANCH, 0b000, None),
    "bne":  ("B", OPCODE_BRANCH, 0b001, None),
    "blt":  ("B", OPCODE_BRANCH, 0b100, None),
    "bge":  ("B", OPCODE_BRANCH, 0b101, None),
    "bltu": ("B", OPCODE_BRANCH, 0b110, None),
    "bgeu": ("B", OPCODE_BRANCH, 0b111, None),

    "lui":   ("U", OPCODE_LUI, None, None),
    "auipc": ("U", OPCODE_AUIPC, None, None),

    "jal": ("J", OPCODE_JAL, None, None),
}

"""
---------------------------------------------------------------------
2. Utilidades de bits
---------------------------------------------------------------------
"""

def to_unsigned32(value):
    return value & 0xFFFFFFFF


def check_fits_signed(value, bits, context):
    lo = -(1 << (bits - 1))
    hi = (1 << (bits - 1)) - 1
    if not (lo <= value <= hi):
        raise ValueError(
            f"Inmediato {value} no cabe en {bits} bits con signo ({context})"
        )




"""
---------------------------------------------------------------------
3. Parsing de un operando de registro o de inmediato
---------------------------------------------------------------------
"""

def parse_register(tok, context):
    tok = tok.strip()
    if tok not in REGISTERS:
        raise ValueError(f"Registro invalido '{tok}' ({context})")
    return REGISTERS[tok]


def parse_immediate(tok, labels=None, current_addr=None, context=""):
    tok = tok.strip()
    if labels is not None and tok in labels:
        return labels[tok] - current_addr
    try:
        return int(tok, 0)  # detecta 0x, 0b, decimal, negativos
    except ValueError:
        raise ValueError(f"Inmediato invalido '{tok}' ({context})")


MEM_OPERAND_RE = re.compile(r"^\s*(-?\w+)\s*\(\s*(x\d+)\s*\)\s*$")


def parse_mem_operand(tok, context):
    m = MEM_OPERAND_RE.match(tok)
    if not m:
        raise ValueError(f"Se esperaba 'inmediato(registro)' en '{tok}' ({context})")
    imm_str, reg_str = m.groups()
    return imm_str, parse_register(reg_str, context)



"""
---------------------------------------------------------------------
4. Codificadores por formato
---------------------------------------------------------------------
"""

def encode_r(opcode, funct3, funct7, rd, rs1, rs2):
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode


def encode_i(opcode, funct3, rd, rs1, imm):
    check_fits_signed(imm, 12, "inmediato tipo I")
    imm_field = to_unsigned32(imm) & 0xFFF
    return (imm_field << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode


def encode_shamt(opcode, funct3, funct7, rd, rs1, shamt):
    if not (0 <= shamt <= 31):
        raise ValueError(f"Shift amount {shamt} fuera de rango (0-31)")
    return (funct7 << 25) | (shamt << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode


def encode_s(opcode, funct3, rs1, rs2, imm):
    check_fits_signed(imm, 12, "inmediato tipo S")
    imm_u = to_unsigned32(imm) & 0xFFF
    imm_11_5 = (imm_u >> 5) & 0x7F
    imm_4_0 = imm_u & 0x1F
    return (imm_11_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm_4_0 << 7) | opcode


def encode_b(opcode, funct3, rs1, rs2, imm):
    if imm % 2 != 0:
        raise ValueError(f"Desplazamiento de branch {imm} debe ser par")
    check_fits_signed(imm, 13, "inmediato tipo B")
    imm_u = to_unsigned32(imm)
    bit12 = (imm_u >> 12) & 0x1
    bit11 = (imm_u >> 11) & 0x1
    bits10_5 = (imm_u >> 5) & 0x3F
    bits4_1 = (imm_u >> 1) & 0xF
    return (bit12 << 31) | (bits10_5 << 25) | (rs2 << 20) | (rs1 << 15) | \
           (funct3 << 12) | (bits4_1 << 8) | (bit11 << 7) | opcode


def encode_u(opcode, rd, imm):
    imm_u = to_unsigned32(imm) & 0xFFFFF
    return (imm_u << 12) | (rd << 7) | opcode


def encode_j(opcode, rd, imm):
    if imm % 2 != 0:
        raise ValueError(f"Desplazamiento de jal {imm} debe ser par")
    check_fits_signed(imm, 21, "inmediato tipo J")
    imm_u = to_unsigned32(imm)
    bit20 = (imm_u >> 20) & 0x1
    bits10_1 = (imm_u >> 1) & 0x3FF
    bit11 = (imm_u >> 11) & 0x1
    bits19_12 = (imm_u >> 12) & 0xFF
    return (bit20 << 31) | (bits19_12 << 12) | (bit11 << 20) | (bits10_1 << 21) | (rd << 7) | opcode




"""
--------------------------------------------------------------------
5. Tokenizado de una linea
---------------------------------------------------------------------
"""

LABEL_RE = re.compile(r"^\s*([A-Za-z_.][A-Za-z0-9_]*)\s*:\s*(.*)$")
DIRECTIVE_PREFIXES = (".section", ".global", ".globl", ".text", ".data")


def strip_comment(line):
    for marker in ("#", "//"):
        idx = line.find(marker)
        if idx != -1:
            line = line[:idx]
    return line.strip()


def split_line(raw_line):
    line = strip_comment(raw_line)
    if not line:
        return None, ""
    m = LABEL_RE.match(line)
    if m:
        label, rest = m.group(1), m.group(2).strip()
        return label, rest
    return None, line


def is_directive(text):
    return any(text.startswith(p) for p in DIRECTIVE_PREFIXES)


def split_instruction(text):
    parts = text.split(None, 1)
    mnemonic = parts[0].lower()
    if len(parts) == 1:
        return mnemonic, []
    operands = [op.strip() for op in parts[1].split(",")]
    return mnemonic, operands




"""
---------------------------------------------------------------------
6. Ensamblado en dos pasadas
---------------------------------------------------------------------
"""

def assemble(lines):
    labels = {}
    addr = 0
    instr_lines = []

    for raw in lines:
        label, rest = split_line(raw)
        if label is not None:
            if label in labels:
                raise ValueError(f"Etiqueta duplicada: {label}")
            labels[label] = addr
        if not rest or is_directive(rest):
            continue
        mnemonic, operands = split_instruction(rest)
        instr_lines.append((addr, mnemonic, operands))
        addr += 4

    words = []
    for addr, mnemonic, operands in instr_lines:
        if mnemonic not in INSTR_TABLE:
            raise ValueError(f"Instruccion desconocida '{mnemonic}' en 0x{addr:08x}")
        fmt, opcode, funct3, funct7 = INSTR_TABLE[mnemonic]
        ctx = f"'{mnemonic}' en 0x{addr:08x}"

        if fmt == "R":
            rd, rs1, rs2 = (parse_register(op, ctx) for op in operands)
            word = encode_r(opcode, funct3, funct7, rd, rs1, rs2)
        elif fmt == "I":
            rd = parse_register(operands[0], ctx)
            rs1 = parse_register(operands[1], ctx)
            imm = parse_immediate(operands[2], context=ctx)
            word = encode_i(opcode, funct3, rd, rs1, imm)
        elif fmt == "SHAMT":
            rd = parse_register(operands[0], ctx)
            rs1 = parse_register(operands[1], ctx)
            shamt = parse_immediate(operands[2], context=ctx)
            word = encode_shamt(opcode, funct3, funct7, rd, rs1, shamt)
        elif fmt == "ILOAD":
            rd = parse_register(operands[0], ctx)
            imm_str, rs1 = parse_mem_operand(operands[1], ctx)
            imm = parse_immediate(imm_str, context=ctx)
            word = encode_i(opcode, funct3, rd, rs1, imm)
        elif fmt == "S":
            rs2 = parse_register(operands[0], ctx)
            imm_str, rs1 = parse_mem_operand(operands[1], ctx)
            imm = parse_immediate(imm_str, context=ctx)
            word = encode_s(opcode, funct3, rs1, rs2, imm)
        elif fmt == "B":
            rs1 = parse_register(operands[0], ctx)
            rs2 = parse_register(operands[1], ctx)
            imm = parse_immediate(operands[2], labels, addr, ctx)
            word = encode_b(opcode, funct3, rs1, rs2, imm)
        elif fmt == "U":
            rd = parse_register(operands[0], ctx)
            imm = parse_immediate(operands[1], context=ctx)
            word = encode_u(opcode, rd, imm)
        elif fmt == "J":
            rd = parse_register(operands[0], ctx)
            imm = parse_immediate(operands[1], labels, addr, ctx)
            word = encode_j(opcode, rd, imm)
        else:
            raise ValueError(f"Formato no implementado: {fmt}")

        words.append(word)

    return words


def main():
    if len(sys.argv) != 3:
        print("Uso: python3 asm.py entrada.s salida.hex")
        sys.exit(1)
    with open(sys.argv[1]) as f:
        lines = f.readlines()
    words = assemble(lines)
    with open(sys.argv[2], "w") as f:
        for w in words:
            f.write(f"{w:08x}\n")


if __name__ == "__main__":
    main()
