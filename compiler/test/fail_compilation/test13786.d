/*
TEST_OUTPUT:
---
fail_compilation/test13786.d(30): Deprecation: `debug = <integer>` is deprecated, use debug identifiers instead
    debug = 123;
            ^
fail_compilation/test13786.d(32): Deprecation: `version = <integer>` is deprecated, use version identifiers instead
    version = 123;
              ^
fail_compilation/test13786.d(30): Error: debug `123` level declaration must be at module level
    debug = 123;
            ^
fail_compilation/test13786.d(31): Error: debug `abc` declaration must be at module level
    debug = abc;
            ^
fail_compilation/test13786.d(32): Error: version `123` level declaration must be at module level
    version = 123;
              ^
fail_compilation/test13786.d(33): Error: version `abc` declaration must be at module level
    version = abc;
              ^
fail_compilation/test13786.d(36): Error: template instance `test13786.T!()` error instantiating
alias X = T!();
          ^
---
*/

template T()
{
    debug = 123;
    debug = abc;
    version = 123;
    version = abc;
}

alias X = T!();
