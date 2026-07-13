/*
TEST_OUTPUT:
---
fail_compilation/fail21740d.i(12): Error: Bidirectional control characters in universal character names are disallowed for security reasons
fail_compilation/fail21740d.i(13): Error: Bidirectional control characters in universal character names are disallowed for security reasons
fail_compilation/fail21740d.i(14): Error: Bidirectional control characters in universal character names are disallowed for security reasons
fail_compilation/fail21740d.i(14): Error: character 0x200e is not allowed as a start character in an identifier
fail_compilation/fail21740d.i(15): Error: Bidirectional control characters in universal character names are disallowed for security reasons
fail_compilation/fail21740d.i(16): Error: Bidirectional control characters in universal character names are disallowed for security reasons
---
*/
int \u061c;
int \u061C;
int \u200e;
int \u202a;
int \u2066;
