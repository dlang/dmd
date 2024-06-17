// See ../README.md for information about DMD unit tests.

module deinitialization;

@("global.deinitialize")
unittest
{
    import dmd.globals : global;

    static void assertStructsEqual(T)(const ref T a, const ref T b)
    if (is(T == struct))
    {
        foreach (i, _; typeof(a.tupleof))
        {
            enum name = __traits(identifier, a.tupleof[i]);

            static if (is(typeof(a.tupleof[i]) == const(char*)))
                assert(a.tupleof[i].fromStringz == b.tupleof[i].fromStringz, name);
            else
                assert(a.tupleof[i] == b.tupleof[i], name);
        }
    }

    immutable init = global.init;
    assertStructsEqual(global, init);

    global._init();
    global.deinitialize();

    assert(global == global.init);
}

@("Type.deinitialize")
unittest
{
    import dmd.target : addDefaultVersionIdentifiers;
    import dmd.mtype : Type;
    import dmd.globals : global;

    assert(Type.stringtable == Type.stringtable.init);

    global._init();

    Type._init();
    Type.deinitialize();

    global.deinitialize();

    assert(Type.stringtable == Type.stringtable.init);
}

@("Id.deinitialize")
unittest
{
    import dmd.id : Id;

    static void assertInitialState()
    {
        foreach (e ; __traits(allMembers, Id))
        {
            static if (!__traits(isStaticFunction, mixin("Id." ~ e)))
                assert(__traits(getMember, Id, e) is null);
        }
    }

    assertInitialState();

    Id.initialize();
    Id.deinitialize();

    assertInitialState();
}

@("Module.deinitialize")
unittest
{
    import dmd.dmodule : Module;

    assert(Module.modules is Module.modules.init);

    Module._init();
    Module.deinitialize();

    assert(Module.modules is Module.modules.init);
}

@("Target.deinitialize")
unittest
{
    import dmd.globals : Param;
    import dmd.dmdparams : setTargetBuildDefaults;
    import dmd.target : target, Target;

    static bool isFPTypeProperties(T)()
    {
        return is(T == const(typeof(Target.FloatProperties))) ||
            is (T == const(typeof(Target.DoubleProperties))) ||
            is (T == const(typeof(Target.RealProperties)));
    }

    static void assertStructsEqual(T)(const ref T a, const ref T b) @nogc pure nothrow
    if (is(T == struct))
    {
        foreach (i, _; typeof(a.tupleof))
        {
            alias Type = typeof(a.tupleof[i]);
            enum name = __traits(identifier, a.tupleof[i]);

            static if (!isFPTypeProperties!Type)
                assert(a.tupleof[i] == b.tupleof[i], name);
        }
    }

    const init = target.init;
    assertStructsEqual(target, init);

    Param params;
    target.setTargetBuildDefaults();
    target._init(params);
    target.deinitialize();

    assertStructsEqual(target, init);
}

@("Expression.deinitialize")
unittest
{
    import dmd.expression : Expression, CTFEExp;

    static void assertInitialState()
    {
        assert(CTFEExp.cantexp is null);
        assert(CTFEExp.voidexp is null);
        assert(CTFEExp.breakexp is null);
        assert(CTFEExp.continueexp is null);
        assert(CTFEExp.gotoexp is null);
        assert(CTFEExp.showcontext is null);
    }

    assertInitialState();

    Expression._init();
    Expression.deinitialize();

    assertInitialState();
}

@("Objc.deinitialize")
unittest
{
    import dmd.objc : Objc, objc;

    assert(objc is null);

    Objc._init();
    Objc.deinitialize();

    assert(objc is null);
}

private inout(char)[] fromStringz(inout(char)* cString) @nogc @system pure nothrow
{
    import core.stdc.string : strlen;
    return cString ? cString[0 .. strlen(cString)] : null;
}
