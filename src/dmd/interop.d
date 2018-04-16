/+
Example usage:
extern (C++) Dstring funLib(Dstring input)
{
    import std.string : toUpper;
    import std.conv : to;
    return input.toNative.toUpper.to!Dstring;
}
+/

extern (C++) struct Darray(T)
{
    size_t length;
    T* ptr;

    extern (D) this(T[] a)
    {
        this.length = a.length;
        this.ptr = a.ptr;
    }

    extern (D) T[] toNative()
    {
        // TODO: could even use a raw cast since ABI is same
        return ptr[0 .. length];
    }
}

alias Dstring = Darray!char;
alias Dcstring = Darray!(const(char));

