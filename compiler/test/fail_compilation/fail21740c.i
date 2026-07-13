/*
TEST_OUTPUT:
---
fail_compilation/fail21740c.i(9): Error: character '\' is not a valid token
fail_compilation/fail21740c.i(10): Error: character '\' is not a valid token
fail_compilation/fail21740c.i(10): Error: missing comma or semicolon after declaration of `é`, found `q` instead
---
*/
int \uq;
int \u00e9\q;
