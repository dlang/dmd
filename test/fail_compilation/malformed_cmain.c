/*
TEST_OUTPUT:
---
fail_compilation/malformed_cmain.c(13): Error: function `malformed_cmain.main` parameters must match one of the following signatures
fail_compilation/malformed_cmain.c(13):        `main()`
fail_compilation/malformed_cmain.c(13):        `main(int argc, char** argv)`
fail_compilation/malformed_cmain.c(13):        `main(int argc, char** argv, char** environ)` [POSIX extension]
---

*/

int main(int argc, char** argv, ...)
{
    return 0;
}
