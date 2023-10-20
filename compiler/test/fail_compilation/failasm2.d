/*
REQUIRED_ARGS: -m32
TEST_OUTPUT:
---
fail_compilation/failasm2.d(108): Error: operand size for opcode `inc` is ambiguous, add `ptr byte/short/int/long` prefix
fail_compilation/failasm2.d(110): Error: operand size for opcode `dec` is ambiguous, add `ptr byte/short/int/long` prefix
fail_compilation/failasm2.d(111): Error: operand size for opcode `imul` is ambiguous, add `ptr byte/short/int/long` prefix
fail_compilation/failasm2.d(112): Error: operand size for opcode `idiv` is ambiguous, add `ptr byte/short/int/long` prefix
fail_compilation/failasm2.d(113): Error: operand size for opcode `mul` is ambiguous, add `ptr byte/short/int/long` prefix
fail_compilation/failasm2.d(114): Error: operand size for opcode `div` is ambiguous, add `ptr byte/short/int/long` prefix
fail_compilation/failasm2.d(115): Error: operand size for opcode `neg` is ambiguous, add `ptr byte/short/int/long` prefix
fail_compilation/failasm2.d(116): Error: operand size for opcode `not` is ambiguous, add `ptr byte/short/int/long` prefix
---
*/

#line 100

// https://issues.dlang.org/show_bug.cgi?id=2617

uint test2617()
{
    asm
    {
        naked;
        inc     [EAX];
        inc     byte ptr [EAX];
        dec     [EAX];
        imul    [EAX];
        idiv    [EAX];
        mul     [EAX];
        div     [EAX];
        neg     [EAX];
        not     [EAX];
    }
}
