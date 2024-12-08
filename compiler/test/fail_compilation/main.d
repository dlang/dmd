/*
TEST_OUTPUT:
---
fail_compilation/main.d(13): Error: only one entry point `main`$?:windows=, `WinMain` or `DllMain`$ is allowed
void main(string[] args) {}
     ^
fail_compilation/main.d(12):        previously found `void main()` here
void main() {}
     ^
---
*/
void main() {}
void main(string[] args) {}
