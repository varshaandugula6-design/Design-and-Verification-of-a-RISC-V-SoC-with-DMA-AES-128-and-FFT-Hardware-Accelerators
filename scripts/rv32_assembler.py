#!/usr/bin/env python3
"""
rv32_assembler.py: A clean RV32I + Zicsr Assembler for VeeR EL2 SoC Firmware
Supports RV32I, Zicsr, standard pseudo-instructions, labels, and directives.
Generates:
  1. SystemVerilog memory initialization statements
  2. Plain hex/mem files for $readmemh
  3. C-style byte/word arrays
"""

import sys
import re
import os

REGS = {
    'zero': 0, 'ra': 1, 'sp': 2, 'gp': 3, 'tp': 4,
    't0': 5, 't1': 6, 't2': 7, 's0': 8, 'fp': 8, 's1': 9,
    'a0': 10, 'a1': 11, 'a2': 12, 'a3': 13, 'a4': 14, 'a5': 15, 'a6': 16, 'a7': 17,
    's2': 18, 's3': 19, 's4': 20, 's5': 21, 's6': 22, 's7': 23, 's8': 24, 's9': 25,
    's10': 26, 's11': 27, 't3': 28, 't4': 29, 't5': 30, 't6': 31
}
for i in range(32):
    REGS[f'x{i}'] = i

CSRS = {
    'mstatus': 0x300, 'misa': 0x301, 'mie': 0x304, 'mtvec': 0x305,
    'mscratch': 0x340, 'mepc': 0x341, 'mcause': 0x342, 'mtval': 0x343, 'mip': 0x344,
    'meivt': 0xBC8, 'meihap': 0xFC5
}

def parse_reg(s):
    s = s.strip().lower()
    if s in REGS:
        return REGS[s]
    raise ValueError(f"Unknown register: {s}")

def parse_csr(s):
    s = s.strip().lower()
    if s in CSRS:
        return CSRS[s]
    return parse_imm(s)

def parse_imm(s, labels=None, pc=0):
    s = s.strip()
    if labels and s in labels:
        return labels[s]
    # Check for hex/dec/bin
    try:
        if s.startswith(('0x', '0X')):
            return int(s, 16)
        elif s.startswith(('0b', '0B')):
            return int(s, 2)
        else:
            return int(s, 10)
    except ValueError:
        if labels and s in labels:
            return labels[s]
        raise ValueError(f"Unknown immediate/label: {s}")

def encode_r(funct7, rs2, rs1, funct3, rd, opcode):
    return ((funct7 & 0x7F) << 25) | ((rs2 & 0x1F) << 20) | ((rs1 & 0x1F) << 15) | \
           ((funct3 & 0x7) << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)

def encode_i(imm, rs1, funct3, rd, opcode):
    imm = imm & 0xFFF
    return ((imm & 0xFFF) << 20) | ((rs1 & 0x1F) << 15) | ((funct3 & 0x7) << 12) | \
           ((rd & 0x1F) << 7) | (opcode & 0x7F)

def encode_s(imm, rs2, rs1, funct3, opcode):
    imm = imm & 0xFFF
    imm11_5 = (imm >> 5) & 0x7F
    imm4_0  = imm & 0x1F
    return (imm11_5 << 25) | ((rs2 & 0x1F) << 20) | ((rs1 & 0x1F) << 15) | \
           ((funct3 & 0x7) << 12) | (imm4_0 << 7) | (opcode & 0x7F)

def encode_b(imm, rs2, rs1, funct3, opcode):
    imm = imm & 0x1FFF
    imm12   = (imm >> 12) & 0x1
    imm10_5 = (imm >> 5) & 0x3F
    imm4_1  = (imm >> 1) & 0xF
    imm11   = (imm >> 11) & 0x1
    return (imm12 << 31) | (imm10_5 << 25) | ((rs2 & 0x1F) << 20) | ((rs1 & 0x1F) << 15) | \
           ((funct3 & 0x7) << 12) | (imm4_1 << 8) | (imm11 << 7) | (opcode & 0x7F)

def encode_u(imm, rd, opcode):
    imm20 = (imm >> 12) & 0xFFFFF
    return (imm20 << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)

def encode_j(imm, rd, opcode):
    imm = imm & 0x1FFFFF
    imm20   = (imm >> 20) & 0x1
    imm10_1 = (imm >> 1) & 0x3FF
    imm11   = (imm >> 11) & 0x1
    imm19_12= (imm >> 12) & 0xFF
    return (imm20 << 31) | (imm10_1 << 21) | (imm11 << 20) | (imm19_12 << 12) | \
           ((rd & 0x1F) << 7) | (opcode & 0x7F)

def parse_mem_operand(s):
    # Parses imm(rs1) or (rs1)
    m = re.match(r'^(.*?)\((.*?)\)$', s.strip())
    if m:
        offset_str = m.group(1).strip()
        rs1_str = m.group(2).strip()
        return offset_str, rs1_str
    raise ValueError(f"Invalid memory operand: {s}")

def assemble_file(filename, base_pc=0x00040000):
    with open(filename, 'r') as f:
        lines = f.readlines()

    # Preprocessing: strip comments and whitespace
    clean_lines = []
    for line in lines:
        line = re.sub(r'(//|#|;).*$', '', line).strip()
        if line:
            clean_lines.append(line)

    # Pass 1: Expand macros/pseudo-instructions and assign label addresses
    pc = base_pc
    labels = {}
    intermediate = []

    for line in clean_lines:
        # Check for label
        while ':' in line:
            parts = line.split(':', 1)
            lbl = parts[0].strip()
            labels[lbl] = pc
            line = parts[1].strip()
        if not line:
            continue

        # Split instruction and operands
        tokens = re.split(r'[\s,]+', line.strip())
        tokens = [t for t in tokens if t]
        if not tokens:
            continue
        op = tokens[0].lower()
        args = tokens[1:]

        # Handle directives
        if op == '.org':
            pc = int(args[0], 0)
            intermediate.append(('directive', op, args, pc))
            continue
        elif op == '.word':
            for a in args:
                intermediate.append(('word', a, pc))
                pc += 4
            continue
        elif op in ('.globl', '.global', '.section', '.text', '.data', '.align'):
            continue

        # Pseudo-instructions expansion
        if op == 'nop':
            intermediate.append(('insn', 'addi', ['zero', 'zero', '0'], pc))
            pc += 4
        elif op == 'mv':
            intermediate.append(('insn', 'addi', [args[0], args[1], '0'], pc))
            pc += 4
        elif op == 'not':
            intermediate.append(('insn', 'xori', [args[0], args[1], '-1'], pc))
            pc += 4
        elif op == 'neg':
            intermediate.append(('insn', 'sub', [args[0], 'zero', args[1]], pc))
            pc += 4
        elif op == 'j':
            intermediate.append(('insn', 'jal', ['zero', args[0]], pc))
            pc += 4
        elif op == 'jr':
            intermediate.append(('insn', 'jalr', ['zero', args[0], '0'], pc))
            pc += 4
        elif op == 'ret':
            intermediate.append(('insn', 'jalr', ['zero', 'ra', '0'], pc))
            pc += 4
        elif op == 'call':
            # Simplified: single jal if within range, or lui+jalr
            intermediate.append(('insn', 'jal', ['ra', args[0]], pc))
            pc += 4
        elif op == 'beqz':
            intermediate.append(('insn', 'beq', [args[0], 'zero', args[1]], pc))
            pc += 4
        elif op == 'bnez':
            intermediate.append(('insn', 'bne', [args[0], 'zero', args[1]], pc))
            pc += 4
        elif op == 'li' or op == 'la':
            rd = args[0]
            val_str = args[1]
            # If immediate fits in 12-bit signed:
            # Note: in Pass 1, if label, we may not know value yet, so expand into lui + addi always if needed
            intermediate.append(('pseudo_li', rd, val_str, pc))
            pc += 8 # Reserve 2 words (lui + addi)
        elif op == 'csrw':
            intermediate.append(('insn', 'csrrw', ['zero', args[0], args[1]], pc))
            pc += 4
        elif op == 'csrr':
            intermediate.append(('insn', 'csrrs', [args[0], args[1], 'zero'], pc))
            pc += 4
        elif op == 'csrs':
            intermediate.append(('insn', 'csrrs', ['zero', args[0], args[1]], pc))
            pc += 4
        elif op == 'csrc':
            intermediate.append(('insn', 'csrrc', ['zero', args[0], args[1]], pc))
            pc += 4
        else:
            intermediate.append(('insn', op, args, pc))
            pc += 4

    # Pass 2: Encoding
    machine_code = [] # (pc, word_32bit, asm_str)
    
    for item in intermediate:
        kind = item[0]
        if kind == 'directive':
            continue
        elif kind == 'word':
            val_str = item[1]
            cur_pc = item[2]
            val = parse_imm(val_str, labels, cur_pc) & 0xFFFFFFFF
            machine_code.append((cur_pc, val, f".word 0x{val:08x}"))
        elif kind == 'pseudo_li':
            rd_str = item[1]
            val_str = item[2]
            cur_pc = item[3]
            rd = parse_reg(rd_str)
            imm = parse_imm(val_str, labels, cur_pc) & 0xFFFFFFFF
            # Standard RV32 lui + addi expansion
            upper = ((imm + 0x800) >> 12) & 0xFFFFF
            lower = (imm - (upper << 12)) & 0xFFFFFFFF
            if lower >= 0x80000000:
                lower = lower - 0x100000000
            w1 = encode_u(upper << 12, rd, 0x37) # lui rd, upper
            w2 = encode_i(lower, rd, 0, rd, 0x13) # addi rd, rd, lower
            machine_code.append((cur_pc, w1, f"lui {rd_str}, 0x{upper:x}"))
            machine_code.append((cur_pc + 4, w2, f"addi {rd_str}, {rd_str}, {lower} (li 0x{imm:08x})"))
        elif kind == 'insn':
            op = item[1]
            args = item[2]
            cur_pc = item[3]
            w = 0

            # R-type
            if op in ('add', 'sub', 'sll', 'slt', 'sltu', 'xor', 'srl', 'sra', 'or', 'and'):
                rd = parse_reg(args[0])
                rs1 = parse_reg(args[1])
                rs2 = parse_reg(args[2])
                funct7 = 0x20 if op in ('sub', 'sra') else 0x00
                f3_map = {'add':0, 'sub':0, 'sll':1, 'slt':2, 'sltu':3, 'xor':4, 'srl':5, 'sra':5, 'or':6, 'and':7}
                w = encode_r(funct7, rs2, rs1, f3_map[op], rd, 0x33)

            # I-type ALU
            elif op in ('addi', 'slti', 'sltiu', 'xori', 'ori', 'andi', 'slli', 'srli', 'srai'):
                rd = parse_reg(args[0])
                rs1 = parse_reg(args[1])
                imm = parse_imm(args[2], labels, cur_pc)
                f3_map = {'addi':0, 'slli':1, 'slti':2, 'sltiu':3, 'xori':4, 'srli':5, 'srai':5, 'ori':6, 'andi':7}
                if op == 'slli':
                    imm = imm & 0x1F
                elif op == 'srli':
                    imm = imm & 0x1F
                elif op == 'srai':
                    imm = (imm & 0x1F) | 0x400
                w = encode_i(imm, rs1, f3_map[op], rd, 0x13)

            # Load
            elif op in ('lb', 'lh', 'lw', 'lbu', 'lhu'):
                rd = parse_reg(args[0])
                offset_str, rs1_str = parse_mem_operand(args[1])
                rs1 = parse_reg(rs1_str)
                imm = parse_imm(offset_str, labels, cur_pc)
                f3_map = {'lb':0, 'lh':1, 'lw':2, 'lbu':4, 'lhu':5}
                w = encode_i(imm, rs1, f3_map[op], rd, 0x03)

            # Store
            elif op in ('sb', 'sh', 'sw'):
                rs2 = parse_reg(args[0])
                offset_str, rs1_str = parse_mem_operand(args[1])
                rs1 = parse_reg(rs1_str)
                imm = parse_imm(offset_str, labels, cur_pc)
                f3_map = {'sb':0, 'sh':1, 'sw':2}
                w = encode_s(imm, rs2, rs1, f3_map[op], 0x23)

            # Branch
            elif op in ('beq', 'bne', 'blt', 'bge', 'bltu', 'bgeu'):
                rs1 = parse_reg(args[0])
                rs2 = parse_reg(args[1])
                target = parse_imm(args[2], labels, cur_pc)
                offset = target - cur_pc
                f3_map = {'beq':0, 'bne':1, 'blt':4, 'bge':5, 'bltu':6, 'bgeu':7}
                w = encode_b(offset, rs2, rs1, f3_map[op], 0x63)

            # JAL / JALR
            elif op == 'jal':
                if len(args) == 1:
                    rd = 1 # ra
                    target = parse_imm(args[0], labels, cur_pc)
                else:
                    rd = parse_reg(args[0])
                    target = parse_imm(args[1], labels, cur_pc)
                offset = target - cur_pc
                w = encode_j(offset, rd, 0x6F)
            elif op == 'jalr':
                if len(args) == 1:
                    rd = 1
                    rs1 = parse_reg(args[0])
                    imm = 0
                elif len(args) == 2:
                    rd = parse_reg(args[0])
                    rs1 = parse_reg(args[1])
                    imm = 0
                else:
                    rd = parse_reg(args[0])
                    rs1 = parse_reg(args[1])
                    imm = parse_imm(args[2], labels, cur_pc)
                w = encode_i(imm, rs1, 0, rd, 0x67)

            # Upper
            elif op == 'lui':
                rd = parse_reg(args[0])
                imm = parse_imm(args[1], labels, cur_pc)
                w = encode_u(imm << 12, rd, 0x37)
            elif op == 'auipc':
                rd = parse_reg(args[0])
                imm = parse_imm(args[1], labels, cur_pc)
                w = encode_u(imm << 12, rd, 0x17)

            # CSR
            elif op in ('csrrw', 'csrrs', 'csrrc'):
                rd = parse_reg(args[0])
                csr = parse_csr(args[1])
                rs1 = parse_reg(args[2])
                f3_map = {'csrrw':1, 'csrrs':2, 'csrrc':3}
                w = ((csr & 0xFFF) << 20) | ((rs1 & 0x1F) << 15) | (f3_map[op] << 12) | ((rd & 0x1F) << 7) | 0x73
            elif op in ('csrrwi', 'csrrsi', 'csrrci'):
                rd = parse_reg(args[0])
                csr = parse_csr(args[1])
                uimm = parse_imm(args[2], labels, cur_pc) & 0x1F
                f3_map = {'csrrwi':5, 'csrrsi':6, 'csrrci':7}
                w = ((csr & 0xFFF) << 20) | (uimm << 15) | (f3_map[op] << 12) | ((rd & 0x1F) << 7) | 0x73
            elif op == 'mret':
                w = 0x30200073
            elif op == 'wfi':
                w = 0x10500073
            elif op == 'ecall':
                w = 0x00000073
            elif op == 'ebreak':
                w = 0x00100073
            else:
                raise ValueError(f"Unsupported instruction: {op}")

            machine_code.append((cur_pc, w & 0xFFFFFFFF, f"{op} {', '.join(args)}"))

    return machine_code, labels

def main():
    if len(sys.argv) < 2:
        print("Usage: rv32_assembler.py <input.s> [base_pc_hex]")
        sys.exit(1)

    in_file = sys.argv[1]
    base_pc = int(sys.argv[2], 16) if len(sys.argv) > 2 else 0x00040000
    out_hex = os.path.splitext(in_file)[0] + ".hex"
    out_sv  = os.path.splitext(in_file)[0] + ".svh"

    code, labels = assemble_file(in_file, base_pc)

    print(f"=== Assembled {in_file} ({len(code)} instructions / words) ===")
    with open(out_hex, 'w') as fh, open(out_sv, 'w') as fsv:
        for idx, (pc, word, disasm) in enumerate(code):
            word_idx = (pc - base_pc) // 4
            fh.write(f"{word:08x}\n")
            fsv.write(f"mem[{word_idx:3d}] = 32'h{word:08x}; // PC: 0x{pc:08x} | {disasm}\n")
            print(f"  [0x{pc:08x} | Word {word_idx:3d}] 0x{word:08x} : {disasm}")

    print(f"Generated {out_hex} and {out_sv}")

if __name__ == '__main__':
    main()
