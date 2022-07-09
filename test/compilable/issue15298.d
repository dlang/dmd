// https://issues.dlang.org/show_bug.cgi?id=15298

// Call alias with a parameter.
void callAlias(alias f)()
{
    f(42);
}

alias Identity(alias X) = X;

void main()
{
    int local;

    // Declare an anonymous function template
    // which writes to a local.
    alias a = Identity!((i) { local = i; });

    // Declare a function template which does
    // the same thing.
    void b(T)(T i) { local = i; }

    callAlias!a; // Works
    callAlias!b; // Error: function test.main.b!int.b is a
                 // nested function and cannot be accessed
                 // from test.callAlias!(b).callAlias
}
