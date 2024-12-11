/*
TEST_OUTPUT:
---
fail_compilation/fail8168.d(11): Error: opcode expected, not `unknown`
        unknown; // wrong opcode
               ^
---
*/
void main() {
    asm {
        unknown; // wrong opcode
    }
}
