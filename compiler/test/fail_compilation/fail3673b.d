/*
TEST_OUTPUT:
---
fail_compilation/fail3673b.d(22): Error: basic type expected, not `if`
class B : if(false) A { }
          ^
fail_compilation/fail3673b.d(22): Error: template constraints only allowed for templates
class B : if(false) A { }
                    ^
fail_compilation/fail3673b.d(22): Error: { } expected following `class` declaration
class B : if(false) A { }
                    ^
fail_compilation/fail3673b.d(22): Error: no identifier for declarator `A`
class B : if(false) A { }
                      ^
fail_compilation/fail3673b.d(22): Error: declaration expected, not `{`
class B : if(false) A { }
                      ^
---
*/
class A {}
class B : if(false) A { }
