/*
TEST_OUTPUT:
---
fail_compilation/fail9199.d(13): Error: function fail9199.fc without 'this' cannot be const
fail_compilation/fail9199.d(14): Error: function fail9199.fi without 'this' cannot be immutable
fail_compilation/fail9199.d(15): Error: function fail9199.fw without 'this' cannot be inout
fail_compilation/fail9199.d(16): Error: function fail9199.fs without 'this' cannot be shared
fail_compilation/fail9199.d(17): Error: function fail9199.fsc without 'this' cannot be shared const
fail_compilation/fail9199.d(18): Error: function fail9199.fsw without 'this' cannot be shared inout
---
*/

void fc() const {}
void fi() immutable {}
void fw() inout {}
void fs() shared {}
void fsc() shared const {}
void fsw() shared inout {}
