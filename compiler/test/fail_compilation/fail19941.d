/*
TEST_OUTPUT:
---
fail_compilation/fail19941.d(28): Error: undefined identifier `dne`
class Auto { int field = &dne; }
                          ^
fail_compilation/fail19941.d(31): Error: undefined identifier `dne`
class Const { int field = &dne; }
                           ^
fail_compilation/fail19941.d(34): Error: undefined identifier `dne`
class Enum { int field = &dne; }
                          ^
fail_compilation/fail19941.d(37): Error: undefined identifier `dne`
class Gshared { int field = &dne; }
                             ^
fail_compilation/fail19941.d(40): Error: undefined identifier `dne`
class Immutable { int field = &dne; }
                               ^
fail_compilation/fail19941.d(43): Error: undefined identifier `dne`
class Shared { int field = &dne; }
                            ^
fail_compilation/fail19941.d(46): Error: undefined identifier `dne`
class Static { int field = &dne; }
                            ^
---
*/
auto a = new Auto;
class Auto { int field = &dne; }

const c = new Const;
class Const { int field = &dne; }

enum e = new Enum;
class Enum { int field = &dne; }

__gshared g = new Gshared;
class Gshared { int field = &dne; }

immutable i = new Immutable;
class Immutable { int field = &dne; }

shared s = new Shared;
class Shared { int field = &dne; }

static t = new Static;
class Static { int field = &dne; }
