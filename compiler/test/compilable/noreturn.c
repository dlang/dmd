// Test attribute "noreturn"

__attribute__(( noreturn, noreturn )) int foo();

__attribute__(( noreturn )) int bar() { return 3; }

int test()
{
    foo();
    bar();
    return 4;
}
