/*
TEST_OUTPUT:
---
fail_compilation/fail8168.d(9): Error: opcode expected, not `unknown`
---
*/
void main() {
    asm {
        unknown; // wrong opcode
    }
}

