/*
TEST_OUTPUT:
---
fail_compilation/truncation_warnings.d(13): Error: implicit conversion from `long` (64 bytes) to `int` (32 bytes) may truncate value
fail_compilation/truncation_warnings.d(13):        Use an explicit cast (e.g., `cast(int)expr`) to silence this.
fail_compilation/truncation_warnings.d(16): Error: implicit conversion from `short` (16 bytes) to `byte` (8 bytes) may truncate value
fail_compilation/truncation_warnings.d(16):        Use an explicit cast (e.g., `cast(byte)expr`) to silence this.
---
*/

void test() {
    long a = 1234;
    int b = a;
    
    short c = 42;
    byte d = c;
}
