/+
TEST_OUTPUT:
---
fail_compilation/malformed_cmain.d($n$): Error: function `malformed_cmain.main` parameters must match one of the following signatures
fail_compilation/malformed_cmain.d($n$):        `main()`
fail_compilation/malformed_cmain.d($n$):        `main(int argc, char** argv)`
fail_compilation/malformed_cmain.d($n$):        `main(int argc, char** argv, char** environ)` [POSIX extension]
---

ARG_SETS: -version=A
ARG_SETS: -version=B
ARG_SETS: -version=C
ARG_SETS: -version=D
ARG_SETS: -version=E
ARG_SETS: -version=F
ARG_SETS: -version=G
+/

extern(C):

version (A) int main(char) { return 0; }

else version (B) int main(int, char) { return 0; }

else version (C) int main(int, char**, bool) { return 0; }

else version (D) int main(int, char**...) { return 0; }

else version (E) int main(int...) { return 0; }

else version (F) int main(lazy int, char**) { return 0; }

else version (G) int main(int, ref char**) { return 0; }
