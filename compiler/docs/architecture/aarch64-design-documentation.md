# AArch64 Inline Assembler: Design Documentation

**Version:** 1.0
**Date:** 2025-11-07
**File:** `compiler/src/dmd/iasm/dmdaarch64.d`
**Related:** aarch64-inline-asm-spec.md, aarch64-implementation-plan.md

## Table of Contents

1. [Overview](#overview)
2. [Architecture and Design Philosophy](#architecture-and-design-philosophy)
3. [Key Data Structures](#key-data-structures)
4. [Parsing Strategy](#parsing-strategy)
5. [Refactoring: Helper Functions](#refactoring-helper-functions)
6. [Instruction Dispatch Mechanism](#instruction-dispatch-mechanism)
7. [Error Handling Strategy](#error-handling-strategy)
8. [Design Patterns Used](#design-patterns-used)
9. [Code Examples](#code-examples)
10. [Lessons Learned](#lessons-learned)

---

## Overview

The AArch64 inline assembler for DMD (`dmdaarch64.d`) provides a clean, maintainable implementation of inline assembly parsing and code generation for the ARM64 architecture. This document explains the design decisions, architecture, and refactoring process that led to the current implementation.

### Goals

- **Simplicity**: Easy to understand and maintain
- **Extensibility**: Easy to add new instructions
- **Correctness**: Generate correct AArch64 machine code
- **Clarity**: Clear error messages for invalid assembly
- **Efficiency**: Minimal code duplication

---

## Architecture and Design Philosophy

### Clean Separation of Concerns

The implementation is organized into distinct layers:

```
┌─────────────────────────────────────────────────┐
│   D Parser (Token Stream)                       │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│   Instruction Dispatch Table                    │
│   (Mnemonic → Handler Function)                 │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│   Instruction Parser Functions                  │
│   (parseInstr_add, parseInstr_ldr, etc.)        │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│   Helper Functions (parseArithmeticAddSub, etc.)│
│   (Reusable parsing logic)                      │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│   Operand Parsers                               │
│   (parseRegister, parseImmediate, parseMemory)  │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│   Encoding Functions (instr.d)                  │
│   (INSTR.add_addsub_imm, INSTR.ldr_imm_gen)    │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│   Machine Code (code* structure)                │
└─────────────────────────────────────────────────┘
```

### Why Not Follow x86?

The x86 inline assembler (`dmdx86.d`) uses a complex opcode table approach with pattern matching. This was intentionally **not** used for AArch64 because:

1. **AArch64 is more regular**: Instructions have predictable encoding patterns
2. **Fewer variants**: Less need for complex pattern matching
3. **Clearer code**: Direct handler functions are easier to understand
4. **Better error messages**: Can provide instruction-specific validation
5. **Easier maintenance**: Adding new instructions is straightforward

### Design Principle: DRY (Don't Repeat Yourself)

Early in development, we identified significant code duplication where nearly identical 90+ line functions existed for related instructions (ADD/ADDS/SUB/SUBS). This led to the **helper function refactoring** described in section 5.

---

## Key Data Structures

### AArch64Operand Structure

The fundamental data structure representing a parsed operand:

```d
struct AArch64Operand
{
    enum Type
    {
        None,
        Register,
        Immediate,
        Memory,
        Label
    }

    Type type;

    // Register operands
    ubyte reg;          // Register number (0-31)
    bool is64bit;       // true for X registers, false for W registers

    // Immediate operands
    long imm;           // Immediate value

    // Memory operands
    ubyte baseReg;      // Base register
    ubyte indexReg;     // Index register (if used)
    long offset;        // Immediate offset
    bool hasIndex;      // True if index register is used
    ExtendOp extend;    // Extend operation for index register
    uint shiftAmount;   // Shift amount for index register
    bool preIndex;      // Pre-indexed addressing mode
    bool postIndex;     // Post-indexed addressing mode

    // Label operands
    Identifier* label;  // Label identifier
}
```

**Design Rationale:**
- Union-style struct saves memory while keeping code clear
- Type tag ensures operands are used correctly
- Separate fields for each addressing mode feature
- `is64bit` flag determines instruction width (critical for encoding)

### Constants and Enumerations

Clean, self-documenting constants replace magic numbers:

```d
private enum ImmediateRange
{
    AddSub12Bit_Min = 0,
    AddSub12Bit_Max = 4095,
    PrePostIndex_Min = -256,
    PrePostIndex_Max = 255,
}

private enum Reg : ubyte
{
    SP = 31,   /// Stack pointer register number
    ZR = 31,   /// Zero register number
    LR = 30,   /// Link register (x30)
}
```

**Design Rationale:**
- Makes code self-documenting
- Prevents magic number errors
- Easier to update if specifications change

---

## Parsing Strategy

### Three-Phase Parsing

Each instruction goes through three phases:

#### Phase 1: Operand Parsing
```d
AArch64Operand dst, src1, src2;
if (!parseRegister(dst))
    return null;
```
- Converts tokens into structured operands
- No validation yet (except syntax)
- Reusable across instructions

#### Phase 2: Semantic Validation
```d
if (dst.type != AArch64Operand.Type.Register)
{
    error(asmstate.loc, "register expected as destination for `%s`", instrName);
    return null;
}

if (dst.is64bit != src1.is64bit)
{
    error(asmstate.loc, "register size mismatch in `%s` instruction", instrName);
    return null;
}
```
- Validates operand types match instruction requirements
- Checks size consistency (X vs W registers)
- Checks immediate ranges
- Provides clear, specific error messages

#### Phase 3: Encoding
```d
uint sf = dst.is64bit ? 1 : 0;
uint encoding = INSTR.addsub_imm(sf, op, S, 0, cast(uint)src2.imm, src1.reg, dst.reg);
return emitInstruction(encoding);
```
- Extracts encoding parameters from operands
- Calls backend encoding function from `instr.d`
- Wraps encoded instruction in `code*` structure

### Operand Parser Design

Operand parsers are **atomic** and **reusable**:

```d
bool parseRegister(ref AArch64Operand op);
bool parseImmediate(ref AArch64Operand op);
bool parseMemoryOperand(ref AArch64Operand op);
```

**Key Properties:**
1. **Side-effect free on error**: If parsing fails, token stream is restored
2. **Type-specific**: Each parser only handles one operand type
3. **Composable**: Can be called in sequence to try alternatives
4. **Boolean return**: `true` = success, `false` = error (with message)

---

## Refactoring: Helper Functions

### The Problem: Code Duplication

**Before refactoring**, instruction parsers looked like this:

```d
private code* parseInstr_add()
{
    AArch64Operand dst, src1, src2;

    // Parse destination register (20 lines)
    if (!parseRegister(dst))
        return null;
    if (dst.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as destination for `add`");
        return null;
    }

    // Parse comma (5 lines)
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after destination register");
        return null;
    }
    asmNextToken();

    // Parse first source register (20 lines)
    if (!parseRegister(src1))
        return null;
    if (src1.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as first source for `add`");
        return null;
    }

    // Validate size match (8 lines)
    if (dst.is64bit != src1.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `add` instruction");
        return null;
    }

    // Parse comma (5 lines)
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after first source register");
        return null;
    }
    asmNextToken();

    uint sf = dst.is64bit ? 1 : 0;
    uint encoding;

    // Check if immediate or register (40 lines)
    if (tokValue() == TOK.identifier && asmstate.tok.ident.toString() == "#")
    {
        // Immediate form
        if (!parseImmediate(src2))
            return null;
        if (!validateImmediateRange(src2.imm, 0, 4095, "add"))
            return null;
        encoding = INSTR.addsub_imm(sf, 0, 0, 0, cast(uint)src2.imm, src1.reg, dst.reg);
    }
    else
    {
        // Register form
        if (!parseRegister(src2))
            return null;
        if (src2.type != AArch64Operand.Type.Register)
        {
            error(asmstate.loc, "register or immediate expected");
            return null;
        }
        if (dst.is64bit != src2.is64bit)
        {
            error(asmstate.loc, "register size mismatch");
            return null;
        }
        encoding = INSTR.addsub_shift(sf, 0, 0, 0, src2.reg, 0, src1.reg, dst.reg);
    }

    return emitInstruction(encoding);
}
```

**The problem**: This exact pattern (with only the instruction name and encoding parameters different) was duplicated for:
- `ADD` (90 lines)
- `ADDS` (90 lines)
- `SUB` (90 lines)
- `SUBS` (90 lines)
- `ADC` (75 lines)
- `ADCS` (75 lines)
- `SBC` (75 lines)
- `SBCS` (75 lines)

**Total duplication**: ~630 lines of nearly identical code!

### The Solution: Helper Functions

We created two helper functions that encapsulate the common parsing logic:

#### 1. `parseArithmeticAddSub` - For ADD/ADDS/SUB/SUBS

```d
/**
 * Helper function for ADD/ADDS/SUB/SUBS style instructions
 * Params:
 *   instrName = instruction name for error messages
 *   op = 0 for ADD, 1 for SUB
 *   S = 0 for non-flag-setting, 1 for flag-setting
 * Returns: encoded instruction or null on error
 */
private code* parseArithmeticAddSub(const(char)* instrName, uint op, uint S)
{
    AArch64Operand dst, src1, src2;

    // Parse and validate all operands (common logic)
    // ...

    // Immediate vs register form handling
    if (isImmediate)
        encoding = INSTR.addsub_imm(sf, op, S, 0, imm, src1.reg, dst.reg);
    else
        encoding = INSTR.addsub_shift(sf, op, S, shift, src2.reg, imm6, src1.reg, dst.reg);

    return emitInstruction(encoding);
}
```

**Key parameters:**
- `instrName`: Used in error messages (e.g., "add", "subs")
- `op`: Encoding bit - 0 for ADD, 1 for SUB
- `S`: Encoding bit - 0 for normal, 1 for flag-setting

#### 2. `parseArithmeticCarry` - For ADC/ADCS/SBC/SBCS

```d
/**
 * Helper function for ADC/ADCS/SBC/SBCS style instructions
 * Params:
 *   instrName = instruction name for error messages
 *   op = 0 for ADC, 1 for SBC
 *   S = 0 for non-flag-setting, 1 for flag-setting
 * Returns: encoded instruction or null on error
 */
private code* parseArithmeticCarry(const(char)* instrName, uint op, uint S)
{
    // Similar pattern but for carry instructions (3 registers, no immediate form)
    // ...
}
```

### After Refactoring: Simple Wrappers

**After refactoring**, each instruction became a simple wrapper:

```d
/// ADD instruction: add Xd, Xn, #imm|Xm
private code* parseInstr_add()
{
    asmNextToken(); // Skip 'add'
    return parseArithmeticAddSub("add", 0, 0); // op=0 (ADD), S=0 (no flags)
}

/// ADDS instruction: adds Xd, Xn, #imm|Xm (add and set flags)
private code* parseInstr_adds()
{
    asmNextToken(); // Skip 'adds'
    return parseArithmeticAddSub("adds", 0, 1); // op=0 (ADD), S=1 (set flags)
}

/// SUB instruction: sub Xd, Xn, #imm|Xm
private code* parseInstr_sub()
{
    asmNextToken(); // Skip 'sub'
    return parseArithmeticAddSub("sub", 1, 0); // op=1 (SUB), S=0 (no flags)
}

/// SUBS instruction: subs Xd, Xn, #imm|Xm (subtract and set flags)
private code* parseInstr_subs()
{
    asmNextToken(); // Skip 'subs'
    return parseArithmeticAddSub("subs", 1, 1); // op=1 (SUB), S=1 (set flags)
}
```

### Refactoring Results

**Code reduction:**
- **Before**: 8 functions × ~85 lines = 680 lines
- **After**: 2 helper functions (~95 lines each) + 8 wrappers (~5 lines each) = 230 lines
- **Reduction**: 450 lines eliminated (66% reduction)

**Benefits:**
1. **Single source of truth**: Parsing logic exists in one place
2. **Easier to fix bugs**: Fix once, fixed for all 8 instructions
3. **Easier to enhance**: Add shift support once, works for all
4. **More readable**: Wrappers clearly show the relationship between instructions
5. **Self-documenting**: Parameters make encoding differences explicit

**Critical bug demonstration**: The `parseOptionalShift` bug (TOK.pound vs TOK.identifier) was fixed **once** in the helper function and immediately fixed for all 8 instructions. If we hadn't refactored, we would have needed to fix the same bug in 8 different places!

---

## Instruction Dispatch Mechanism

### Dispatch Table

Instructions are mapped to handler functions via a dispatch table:

```d
private immutable InstructionHandler[string] instructionTable;

static this()
{
    instructionTable = [
        // Data movement
        "mov": &parseInstr_mov,
        "ldr": &parseInstr_ldr,
        "str": &parseInstr_str,

        // Arithmetic
        "add": &parseInstr_add,
        "adds": &parseInstr_adds,
        "sub": &parseInstr_sub,
        "subs": &parseInstr_subs,
        "adc": &parseInstr_adc,
        "adcs": &parseInstr_adcs,
        "sbc": &parseInstr_sbc,
        "sbcs": &parseInstr_sbcs,
        "cmn": &parseInstr_cmn,

        // ... more instructions
    ];
}
```

### Lookup and Dispatch

```d
code* inlineAsmAArch64Semantic(...)
{
    // Get instruction mnemonic
    if (tokValue() != TOK.identifier)
    {
        error(asmstate.loc, "instruction expected");
        return null;
    }

    string mnemonic = asmstate.tok.ident.toString();

    // Look up handler (case-insensitive)
    auto handler = mnemonic.toLower() in instructionTable;
    if (!handler)
    {
        error(asmstate.loc, "unknown AArch64 instruction: %s", mnemonic);
        return null;
    }

    // Call handler
    return (*handler)();
}
```

**Design Benefits:**
1. **O(1) lookup**: Fast instruction matching
2. **Easy to extend**: Just add new entry
3. **Case-insensitive**: Handles MOV, mov, Mov, etc.
4. **Clear errors**: "unknown instruction" is obvious
5. **Type-safe**: D's type system ensures handlers match signature

---

## Error Handling Strategy

### Fail-Fast Philosophy

Errors are detected as early as possible:

```d
// Bad: Parse everything then validate
// (Could give confusing errors on second operand when first is wrong)

// Good: Validate immediately
if (!parseRegister(dst))
    return null;  // Error already reported

if (dst.type != AArch64Operand.Type.Register)
{
    error(asmstate.loc, "register expected as destination");
    return null;  // Fail immediately
}
```

### Specific Error Messages

Error messages include:
1. **Context**: What instruction/operation failed
2. **What was expected**: "register expected"
3. **What was found**: "got immediate"
4. **Location**: File, line, column

```d
error(asmstate.loc,
      "register size mismatch in `%s` instruction: expected %s but got %s",
      instrName,
      dst.is64bit ? "x register" : "w register",
      src.is64bit ? "x register" : "w register");
```

### Validation Helpers

Reusable validation functions:

```d
bool validateImmediateRange(long value, long min, long max, const(char)* instrName)
{
    if (value < min || value > max)
    {
        error(asmstate.loc,
              "immediate value %lld out of range for `%s` (must be %lld..%lld)",
              value, instrName, min, max);
        return false;
    }
    return true;
}
```

---

## Design Patterns Used

### 1. Command Pattern (Instruction Handlers)

Each instruction has a handler function that encapsulates:
- Parsing logic
- Validation logic
- Encoding logic

```d
alias InstructionHandler = code* function();
```

### 2. Strategy Pattern (Operand Parsing)

Different strategies for parsing different operand types:
```d
bool parseRegister(ref AArch64Operand op);
bool parseImmediate(ref AArch64Operand op);
bool parseMemoryOperand(ref AArch64Operand op);
```

### 3. Template Method Pattern (Helper Functions)

Helper functions define the parsing algorithm skeleton, with specific steps filled in by parameters:

```d
parseArithmeticAddSub(instrName, op, S)
{
    // Template algorithm:
    // 1. Parse destination register
    // 2. Parse source register
    // 3. Parse immediate OR register
    // 4. Encode with specific op and S bits
}
```

### 4. Flyweight Pattern (Constants)

Shared constant definitions reduce memory:
```d
private enum ImmediateRange { ... }
private enum Reg { SP = 31, ZR = 31, LR = 30 }
```

### 5. Adapter Pattern (INSTR Interface)

Parser code adapts parsed operands to backend encoding functions:

```d
// Parser produces: dst.reg, src1.reg, src2.imm
// Backend expects: (sf, op, S, sh, imm12, Rn, Rd)

uint encoding = INSTR.addsub_imm(sf, op, S, 0, cast(uint)src2.imm, src1.reg, dst.reg);
//                                 ↑   ↑   ↑   ↑   ↑                ↑          ↑
//                                 Adapter layer extracts and arranges parameters
```

---

## Code Examples

### Example 1: Simple Instruction (MOV)

```d
private code* parseInstr_mov()
{
    asmNextToken(); // Skip 'mov' token

    AArch64Operand dst, src;

    // Parse destination register
    if (!parseRegister(dst) || dst.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "destination register expected for `mov`");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected");
        return null;
    }
    asmNextToken();

    // Parse source register
    if (!parseRegister(src) || src.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "source register expected for `mov`");
        return null;
    }

    // Validate size match
    if (dst.is64bit != src.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `mov`");
        return null;
    }

    // Encode and emit
    uint sf = dst.is64bit ? 1 : 0;
    uint encoding = INSTR.mov_register(sf, src.reg, dst.reg);
    return emitInstruction(encoding);
}
```

**Assembly**: `mov x0, x1`
**Parsing**: dst=x0 (reg=0, is64bit=true), src=x1 (reg=1, is64bit=true)
**Encoding**: INSTR.mov_register(1, 1, 0) → 0xAA0103E0

### Example 2: Complex Instruction with Variants (ADD/ADDS/SUB/SUBS)

Thanks to the helper function, all four variants share common logic:

```d
// Wrapper for ADD
private code* parseInstr_add()
{
    asmNextToken();
    return parseArithmeticAddSub("add", 0, 0);
}

// The helper function handles all the complexity:
private code* parseArithmeticAddSub(const(char)* instrName, uint op, uint S)
{
    // Parse 3 operands with full validation
    // Handle immediate vs register forms
    // Support optional shifts
    // Generate appropriate encoding
}
```

**Assembly Examples**:
- `add x0, x1, #42` → Immediate form
- `add x0, x1, x2` → Register form
- `add x0, x1, x2, lsl #3` → Register with shift
- `adds x0, x1, x2` → Flag-setting variant (S=1)
- `sub x0, x1, x2` → Subtraction (op=1)

### Example 3: Memory Operations (LDR/STR)

```d
private code* parseInstr_ldr()
{
    asmNextToken();

    AArch64Operand dst, mem;

    // Parse destination register
    if (!parseRegister(dst))
        return null;

    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected");
        return null;
    }
    asmNextToken();

    // Parse memory operand
    if (!parseMemoryOperand(mem))
        return null;

    // Validate and encode based on addressing mode
    // ...
}
```

**Assembly Examples**:
- `ldr x0, [x1]` → Base register only
- `ldr x0, [x1, #8]` → Base + immediate offset
- `ldr x0, [x1, x2]` → Base + register offset
- `ldr x0, [x1, #8]!` → Pre-indexed mode
- `ldr x0, [x1], #8` → Post-indexed mode

---

## Lessons Learned

### 1. Refactor Early

**Lesson**: When you notice duplication, refactor immediately. Don't wait.

**Story**: We initially implemented ADD, SUB, ADC, SBC without helpers. When we added ADDS, SUBS, ADCS, SBCS, the duplication became obvious. Refactoring saved hundreds of lines and prevented bugs.

### 2. Test Encoding, Not Just Parsing

**Lesson**: End-to-end tests are critical.

**Story**: Our verification tests only called encoding functions directly (e.g., `INSTR.addsub_shift(...)`), so the `parseOptionalShift` bug wasn't caught. The tests passed, but actual assembly parsing would have failed.

**Recommendation**: Add tests that parse actual assembly text and verify the complete pipeline.

### 3. Token Handling Is Tricky

**Lesson**: Document token types and test edge cases.

**Story**: We assumed `#` would be `TOK.pound`, but it's actually `TOK.identifier` with string value "#". This wasn't obvious from the codebase.

**Recommendation**: Create a token handling reference document for future maintainers.

### 4. Helper Functions Need Clear Contracts

**Lesson**: Document what parameters mean and why they exist.

**Story**: The `op` and `S` parameters to `parseArithmeticAddSub` directly correspond to ARM64 encoding bits. This should be documented.

**Example**:
```d
/**
 * Params:
 *   op = ARM64 encoding bit [30]: 0 for ADD, 1 for SUB
 *   S = ARM64 encoding bit [29]: 0 for normal, 1 for flag-setting
 */
```

### 5. Error Messages Matter

**Lesson**: Invest time in clear, specific error messages.

**Impact**: Good error messages reduce debugging time for users and make the implementation more robust.

**Example**:
```d
// Bad:
error(asmstate.loc, "invalid operand");

// Good:
error(asmstate.loc,
      "register size mismatch in `%s`: cannot mix x register (%s) with w register (%s)",
      instrName, dstReg, srcReg);
```

### 6. Constants Beat Magic Numbers

**Lesson**: Every magic number should be a named constant.

**Before**:
```d
if (amount > 31) // What does 31 mean?
```

**After**:
```d
if (amount > ImmediateRange.MaxBitPos32) // Clear!
```

### 7. Design for Extension

**Lesson**: Make adding new instructions trivial.

**Current**: To add a new instruction:
1. Write parser function (or use helper)
2. Add entry to dispatch table
3. Done!

This low barrier encourages complete implementation.

---

## Future Improvements

### 1. End-to-End Testing

Add tests that parse assembly text and verify encoding:

```d
unittest
{
    auto code = parseAsmString("add x0, x1, x2, lsl #3");
    assert(code.Iop == 0x8B020C20);
}
```

### 2. Instruction Templates

Consider a more declarative approach for simple instructions:

```d
mixin InstructionTemplate!(
    "adc",                          // Mnemonic
    ThreeRegisterOperands,          // Operand pattern
    &INSTR.adc,                     // Encoding function
    "ADC: Add with carry"           // Description
);
```

### 3. Better Token Handling

Create wrapper functions for common token patterns:

```d
bool expectComma();
bool expectRegister(out AArch64Operand op, string context);
bool expectImmediate(out AArch64Operand op, string context);
```

### 4. Symbolic Constants for Encoding

Define constants for encoding bit positions:

```d
enum EncodingBits
{
    SF = 31,   // Size flag bit position
    OP = 30,   // Operation bit position
    S = 29,    // Set flags bit position
}

uint encoding = (sf << EncodingBits.SF) | (op << EncodingBits.OP) | (S << EncodingBits.S) | ...;
```

### 5. Parser State Machine

Consider a state machine for complex instructions:

```d
class InstructionParser
{
    State parseDestination();
    State parseComma();
    State parseSource();
    State parseOptionalModifier();
    State encode();
}
```

---

## Appendix: File Organization

### Current Structure

```
compiler/src/dmd/iasm/dmdaarch64.d (3000+ lines)
├── Constants and Enumerations (lines 1-150)
├── State Management (lines 150-250)
├── Operand Parsing (lines 250-800)
│   ├── parseRegister
│   ├── parseImmediate
│   ├── parseMemoryOperand
│   └── parseOptionalShift
├── Helper Functions (lines 800-1400)
│   ├── parseArithmeticAddSub
│   └── parseArithmeticCarry
├── Instruction Parsers (lines 1400-3000)
│   ├── Data Movement (MOV, LDR, STR, LDP, STP)
│   ├── Arithmetic (ADD, SUB, MUL, DIV, etc.)
│   ├── Logical (AND, ORR, EOR, etc.)
│   ├── Bit Manipulation (LSL, LSR, UBFM, etc.)
│   └── Control Flow (B, BL, BR, RET, etc.)
└── Dispatch Table (end of file)
```

### Organization Principles

1. **Top-down reading**: Most general concepts first, specifics later
2. **Logical grouping**: Related functions near each other
3. **Dependencies before uses**: Helpers before instructions that use them
4. **Comments as headers**: Clear section markers

---

## Summary

The AArch64 inline assembler demonstrates several key principles:

1. **Clean Architecture**: Layered design with clear separation of concerns
2. **Code Reuse**: Helper functions eliminate duplication
3. **Extensibility**: Adding new instructions is straightforward
4. **Correctness**: Strong validation catches errors early
5. **Maintainability**: Clear code structure and documentation

The refactoring from duplicated instruction parsers to helper functions reduced code by 450 lines (66%) while improving maintainability and catching a critical bug that would have affected 8 instructions.

This design serves as a model for implementing inline assemblers for other architectures in DMD.

---

## References

- **ARM Architecture Reference Manual**: Official AArch64 specification
- **dmd/backend/arm/instr.d**: Backend encoding functions
- **aarch64-inline-asm-spec.md**: Specification document
- **aarch64-implementation-plan.md**: Implementation roadmap

---

**Document History**:
- v1.0 (2025-11-07): Initial design documentation
