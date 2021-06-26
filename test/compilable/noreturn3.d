/*
REQUIRED_ARGS: -w -o-

More complex examples from the DIP
https://github.com/dlang/DIPs/blob/master/DIPs/accepted/DIP1034.md
*/

alias noreturn = typeof(*null);
static assert (!is(noreturn == void));

int function() lambdaExit = () => assert(0);

struct Matcher
{
    int value;
    string error;

    int match(handlers...)()
    {
        if (error)
            return handlers[1](error);
        else
            return handlers[0](value);
    }

    int getValue()
    {
        return match!(
            (int v) => v,
            (string e) { throw new Exception(""); }
        )();
    }
}

/* Crashes
enum NoReturn : noreturn
{
    a = noreturn.init,
    b = noreturn.init
}
*/
