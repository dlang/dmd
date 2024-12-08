/*
TEST_OUTPUT:
---
fail_compilation/diag1566.d(35): Error: multiple ! arguments are not allowed
    static assert(is(long == T!(3)!('b')));
                                  ^
fail_compilation/diag1566.d(36): Error: multiple ! arguments are not allowed
    static assert(is(long == T! 3 ! 'b' ));
                                  ^
fail_compilation/diag1566.d(37): Error: multiple ! arguments are not allowed
    static assert(is(long == T!(3)! 'b' ));
                                  ^
fail_compilation/diag1566.d(38): Error: multiple ! arguments are not allowed
    static assert(is(long == T! 3 !('b')));
                                  ^
fail_compilation/diag1566.d(40): Error: multiple ! arguments are not allowed
    static assert(is(long == T!(3)! 'b' !"s"));
                                  ^
fail_compilation/diag1566.d(41): Error: multiple ! arguments are not allowed
    static assert(is(long == T! 3 !('b')!"s"));
                                  ^
---
*/

template T(int n)
{
    template T(char c)
    {
        alias long T;
    }
}

void main()
{
    static assert(is(long == T!(3)!('b')));
    static assert(is(long == T! 3 ! 'b' ));
    static assert(is(long == T!(3)! 'b' ));
    static assert(is(long == T! 3 !('b')));

    static assert(is(long == T!(3)! 'b' !"s"));
    static assert(is(long == T! 3 !('b')!"s"));
}
