module core.internal.lifetime;

import core.lifetime : forward;

/+
emplaceRef is a package function for druntime internal use. It works like
emplace, but takes its argument by ref (as opposed to "by pointer").
This makes it easier to use, easier to be safe, and faster in a non-inline
build.
Furthermore, emplaceRef optionally takes a type parameter, which specifies
the type we want to build. This helps to build qualified objects on mutable
buffer, without breaking the type system with unsafe casts.
+/
void emplaceRef(T, UT, Args...)(ref UT chunk, auto ref Args args)
{
    static if (args.length == 0)
    {
        static assert(is(typeof({static T i;})),
            "Cannot emplace a " ~ T.stringof ~ " because " ~ T.stringof ~
            ".this() is annotated with @disable.");
        static if (is(T == class)) static assert(!__traits(isAbstractClass, T),
            T.stringof ~ " is abstract and it can't be emplaced");
        emplaceInitializer(chunk);
    }
    else static if (
        !is(T == struct) && Args.length == 1 /* primitives, enums, arrays */
        ||
        Args.length == 1 && is(typeof({T t = forward!(args[0]);})) /* conversions */
        ||
        is(typeof(T(forward!args))) /* general constructors */)
    {
        static struct S
        {
            T payload;
            this()(auto ref Args args)
            {
                static if (is(typeof(payload = forward!args)))
                    payload = forward!args;
                else
                    payload = T(forward!args);
            }
        }
        if (__ctfe)
        {
            static if (is(typeof(chunk = T(forward!args))))
                chunk = T(forward!args);
            else static if (args.length == 1 && is(typeof(chunk = forward!(args[0]))))
                chunk = forward!(args[0]);
            else assert(0, "CTFE emplace doesn't support "
                ~ T.stringof ~ " from " ~ Args.stringof);
        }
        else
        {
            S* p = () @trusted { return cast(S*) &chunk; }();
            static if (UT.sizeof > 0)
                emplaceInitializer(*p);
            p.__ctor(forward!args);
        }
    }
    else static if (is(typeof(chunk.__ctor(forward!args))))
    {
        // This catches the rare case of local types that keep a frame pointer
        emplaceInitializer(chunk);
        chunk.__ctor(forward!args);
    }
    else
    {
        //We can't emplace. Try to diagnose a disabled postblit.
        static assert(!(Args.length == 1 && is(Args[0] : T)),
            "Cannot emplace a " ~ T.stringof ~ " because " ~ T.stringof ~
            ".this(this) is annotated with @disable.");

        //We can't emplace.
        static assert(false,
            T.stringof ~ " cannot be emplaced from " ~ Args[].stringof ~ ".");
    }
}

// ditto
static import core.internal.traits;
void emplaceRef(UT, Args...)(ref UT chunk, auto ref Args args)
if (is(UT == core.internal.traits.Unqual!UT))
{
    emplaceRef!(UT, UT)(chunk, forward!args);
}

//emplace helper functions
private nothrow pure @trusted
void emplaceInitializer(T)(scope ref T chunk)
{
    // Emplace T.init.
    // Previously, an immutable static and memcpy were used to hold an initializer.
    // With improved unions, this is no longer needed.
    union UntypedInit
    {
        T dummy;
    }
    static struct UntypedStorage
    {
        align(T.alignof) void[T.sizeof] dummy;
    }

    () @trusted {
        *cast(UntypedStorage*) &chunk = cast(UntypedStorage) UntypedInit.init;
    } ();
}

/*
Simple swap function.
*/
void swap(T)(ref T lhs, ref T rhs)
{
    import core.lifetime : move, moveEmplace;

    T tmp = move(lhs);
    moveEmplace(rhs, lhs);
    moveEmplace(tmp, rhs);
}
