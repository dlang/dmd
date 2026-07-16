module core.sys.wasi.wit_common;

import core.attribute : mustuse;
import ldc.attributes : llvmAttr;

alias wasmImport(string mod, string name) = AliasSeq!(
    llvmAttr("wasm-import-module", mod),
    llvmAttr("wasm-import-name", name)
);

enum wasmExport(string name) = llvmAttr("wasm-export-name", name);

struct witExport { string mod; string name; }

/// Thin CABI compliant wrapper over `T[]`
struct WitList(T) {
@safe @nogc pure nothrow:
    T* ptr;
    size_t length;

    this(inout T[] slice) inout @trusted {
        ptr = slice.ptr;
        length = slice.length;
    }

    void opAssign(T[] slice) @trusted {
        ptr = slice.ptr;
        length = slice.length;
    }

    alias asSlice this;
    inout(T)[] asSlice() @trusted inout {
        return (ptr && length) ? ptr[0..length] : null;
    }

    bool opEquals(in T[] other) const => this[] == other;
    size_t toHash() const => this[].hashOf;
}
auto witList(T : U[], U)(inout T slice) => inout WitList!U(slice);

// WIT ABI for string matches List,
// except list<char> in WIT is actually List!(dchar)
//
// We assume UTF-8 data (as D native strings are UTF-8)
alias WitString = WitList!(char);

// TODO: split this file up and give Tuple a full port of the Phobos version?
/// adapted from Phobos std.typecons.Tuple
/// No support for naming members.
struct Tuple(Types...) if (is(Types)) {
    Types expand;
    alias expand this;
}

mixin template WitFlags(T) if (__traits(isUnsigned, T)) {
    private alias F = typeof(this);

    T bits;

    @safe nothrow @nogc pure:

    static typeof(this) opIndex(size_t i)
    in(i < T.sizeof*8) => F(cast(T)(1 << i));

    auto opUnary(string op : "~")() const => F(~bits);

    auto ref opOpAssign(string op)(F rhs)
    if (op == "|" || op == "&" || op == "^")
    {
        mixin("bits "~op~"= rhs.bits;");
        return this;
    }

    auto opBinary(string op)(F flags) const
    if (op == "|" || op == "&" || op == "^")
    {
        F result = this;
        result.opOpAssign!op(flags);
        return result;
    }

    typeof(this) witClone() const { return this; }
}


mixin template WitVariant(Types...) {
private:
    static assert(is(typeof(this).Tag));
    static assert(is(Tag U == enum) && __traits(isIntegral, U));

    static assert(__traits(allMembers, Tag).length == Types.length);
    static foreach (i, M; __traits(allMembers, Tag)) {
        static assert(i == __traits(getMember, Tag, M));
    }

    union Storage {
        template ReplacedTypes() {
            alias ReplacedTypes = AliasSeq!();

            static foreach (T; Types) {
                static if (is(T == void))
                    ReplacedTypes = AliasSeq!(ReplacedTypes, void[0]);
                else
                    ReplacedTypes = AliasSeq!(ReplacedTypes, T);
            }
        }

        ubyte __zeroinit = 0;
        ReplacedTypes!() members;
    }

    Tag _tag;
    Storage _storage;


    @disable this();

    this(Tag tag, inout Storage storage = Storage.init) inout @nogc nothrow @trusted {
      _tag = tag;
      _storage = storage;
    }


    static auto _create(Tag tag)() if (is(Types[tag] == void)) {
        return typeof(this)(tag);
    }
    static auto _create(Tag tag)(inout Types[tag] val) if (!is(Types[tag] == void)) {
        Storage storage = Storage.init;
        storage.tupleof[tag+1] = cast(Types[tag])val;
        return inout typeof(this)(tag, cast(inout(Storage))storage);
    }

    ref auto _get(Tag tag)() inout return if (!is(Types[tag] == void))
    in (_tag == tag) do { return cast(inout)_storage.tupleof[tag+1]; }
}

/// Based on Rust's Option
struct Option(T) {
private:
    bool _present = false;
    T _value;

    this(bool present, inout T value) inout @safe @nogc nothrow {
        _present = present;
        _value = value;
    }
public:
    static inout(Option) some(inout T value) @safe @nogc nothrow {
        return inout Option(true, value);
    }

    static Option none() @safe @nogc nothrow {
        return Option(false, T.init);
    }

    bool isSome() const @safe @nogc nothrow => _present;
    alias isSome this; // implicit conversion to bool

    bool isNone() const @safe @nogc nothrow => !_present;

    ref inout(T) unwrap() inout @trusted @nogc nothrow return
    in (_present) do { return _value; }

    T unwrapOr(T fallback) @trusted @nogc nothrow => _present ? _value : fallback;

    T unwrapOrElse(D)(scope D fallback)
    if (is(D R == return) && is(R : T) && is(D == __parameters))
    { return _present ? _value : fallback(); }
}

auto some(T)(inout T value) @safe @nogc nothrow {
    return Option!T.some(value);
}

auto none(T)() @safe @nogc nothrow {
    return Option!T.none;
}

/// Based on Rust's Result
@mustuse
struct Result(T = void, E = void) {
private:
    bool _hasError;
    union Storage {
        ubyte __zeroinit = 0;
        static if (!is(T == void)) {
            T value;
        }
        static if (!is(E == void)) {
            E error;
        }
    }
    Storage _storage;

    this(bool hasError, inout(Storage) storage) inout @safe @nogc nothrow {
        _hasError = hasError;
        _storage = storage;
    }

public:
    static if (is(T == void)) {
        static Result ok() @safe @nogc nothrow => Result(false, Storage.init);
    } else {
        static Result ok(inout(T) value) @trusted @nogc nothrow {
            Storage newStorage = Storage.init;
            newStorage.value = cast(T)value;

            return Result(false, cast(inout Storage)newStorage);
        }
    }

    static if (is(E == void)) {
        static Result err() @safe @nogc nothrow => Result(true, Storage.init);
    } else {
        static inout(Result) err(inout(E) error) @trusted @nogc nothrow {
            Storage newStorage = Storage.init;
            newStorage.error = cast(E)error;

            return inout Result(true, cast(inout Storage)newStorage);
        }
    }

    bool isOk() const @safe @nogc nothrow => !_hasError;

    bool isErr() const @safe @nogc nothrow => _hasError;
    alias isErr this; // implicit conversion to bool

    static if (!is(T == void)) {
        ref inout(T) unwrap() inout @trusted @nogc nothrow return
        in (isOk) do { return _storage.value; }

        T unwrapOr(T fallback) @trusted @nogc nothrow => isOk ? _storage.value : fallback;

        T unwrapOrElse(D)(scope D fallback)
        if (is(D R == return) && is(R : T) && is(D == __parameters))
        { return isOk ? _storage.value : fallback(); }
    }

    static if (!is(E == void)) {
        ref inout(E) unwrapErr() inout @trusted @nogc nothrow return
        in (isErr) do { return _storage.error; }
    }
}


void witFree(T)(scope ref T val) @nogc nothrow if (__traits(isArithmetic, T)) {
    // no-op
}
T witClone(T)(in T val) @nogc nothrow if (__traits(isArithmetic, T)) {
    return val;
}

void witFree(T : Option!U, U)(scope ref T val) @nogc nothrow {
    static if (!is(U == void)) if (val.isSome) val.unwrap.witFree;
}
T witClone(T : Option!U, U)(in T val) {
    if (val.isSome) {
        static if (!is(U == void)) {
            return T.some(val.unwrap.witClone);
        } else {
            return T.some;
        }
    } else {
        return T.none;
    }
}

void witFree(T : Result!(U, V), U, V)(scope ref T val) @nogc nothrow {
    if (val.isErr) {
        static if (!is(V == void)) val.unwrapErr.witFree;
    } else {
        static if (!is(U == void)) val.unwrap.witFree;
    }
}
T witClone(T : Result!(U, V), U, V)(in T val) @nogc nothrow {
    if (val.isErr) {
        static if (!is(V == void)) {
            return T.err(val.unwrapErr.witClone);
        } else {
            return T.err;
        }
    } else {
        static if (!is(U == void)) {
            return T.ok(val.unwrap.witClone);
        } else {
            return T.ok;
        }
    }
}

void witFree(T : WitList!U, U)(scope ref T val) @nogc nothrow {
    foreach (ref e; val) {
        e.witFree;
    }
    if (val.ptr && val.length) free(val.ptr);
    val = null;
}
T witClone(T : WitList!U, U)(in T val) @nogc nothrow {
    if (val.ptr == null || val.length == 0) return T(null);

    auto clone = mallocSlice!U(val.length);

    foreach (i, ref e; clone) {
        e = val[i].witClone;
    }

    return clone.witList;
}

void witFree(T : Tuple!U, U...)(scope ref T val) @nogc nothrow {
    static foreach (F; T.tupleof) {
        __traits(child, val, F).witFree;
    }
}
T witClone(T : Tuple!U, U...)(in T val) @nogc nothrow {
    T clone;
    static foreach (F; T.tupleof) {
        __traits(child, clone, F) = __traits(child, val, F).witClone;
    }
    return clone;
}


void witFree(T : U[L], U, size_t L)(scope ref T val) @nogc nothrow {
    foreach (ref e; val) {
        e.witFree;
    }
}
T witClone(T : U[L], U, size_t L)(in T val) @nogc nothrow {
    T clone;
    foreach (i, ref e; clone) {
        e = val[i].witClone;
    }
    return clone;
}

package:

package import core.stdc.stdlib : malloc, free;

// from https://github.com/Inochi2D/numem/blob/main/source/numem/casting.d
// Copyright © 2023-2025, Kitsunebi Games
// Copyright © 2023-2025, Inochi2D Project
// License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
// Authors:   Luna Nielsen
pragma(inline, true)
auto ref T reinterpretCast(T, U)(auto ref U from) @trusted if (T.sizeof == U.sizeof) {
    union tmp { U from; T to; }
    return tmp(from).to;
}

auto mallocSlice(T)(size_t count) @nogc nothrow {
    auto ptr = malloc(count*T.sizeof);
    if (ptr is null) return null;

    return (cast(T*)ptr)[0..count];
}

// from std.meta
alias AliasSeq(T...) = T;


template findWitExportFunc(string mod, string name, Sig, bool implicitSelf, Impl...) {
    static foreach(Func; Impl) {
        static foreach(uda; __traits(getAttributes, Func)) {
            static if (!is(uda) && is(typeof(uda) == witExport) && uda == witExport(mod, name)) {
                static assert(
                    !is(Func) &&
                    (is(typeof(Func) == function)),
                    "The implementation of '", mod, "#", name, "' ",
                    "`", __traits(fullyQualifiedName, findWitExportFunc), "` ",
                    "must be a function or method."
                );

                static assert(
                    !is(typeof(findWitExportFunc) == void) || __traits(isSame, findWitExportFunc, Func),
                    "There must be only one implementation of '", mod, "#", name, "'. ",
                    "Found at least `", __traits(fullyQualifiedName, findWitExportFunc),
                    "` and `", __traits(fullyQualifiedName, Func), "`."
                );
                alias findWitExportFunc = Func;
            }
        }
    }

    static assert(
        !is(typeof(findWitExportFunc) == void),
        "Could not find implementation for '", mod, "#", name, "'"
    );

    static assert(
        is(typeof(&findWitExportFunc) : Sig) && __traits(isStaticFunction, findWitExportFunc) != implicitSelf,
        "The implementation of '", mod, "#", name, "' ",
        "`", __traits(fullyQualifiedName, findWitExportFunc), "` ",
        "must conform to the necessary signature. ",
        "Found `", typeof(&findWitExportFunc), "`",
        ", but expected `", Sig, "`"
    );
}

template findWitExportResource(string mod, string name, Impl...) {
    static foreach(Resource; Impl) {
        static foreach(uda; __traits(getAttributes, Resource)) {
            static if (!is(uda) && is(typeof(uda) == witExport) && uda == witExport(mod, name)) {
                static assert(
                    is(Resource == struct),
                    "The implementation of '", mod, "#", name, "' ",
                    "`", __traits(fullyQualifiedName, findWitExportResource), "` ",
                    "must be a struct."
                );

                static assert(
                    !is(typeof(findWitExportResource) == void) || __traits(isSame, findWitExportResource, Resource),
                    "There must be only one implementation of '", mod, "#", name, "'. ",
                    "Found at least `", __traits(fullyQualifiedName, findWitExportResource),
                    "` and `", __traits(fullyQualifiedName, Resource), "`."
                );
                alias findWitExportResource = Resource;
            }
        }
    }

    static assert(
        !is(typeof(findWitExportResource) == void),
        "Could not find implementation for '", mod, "#", name, "'"
    );
}


template witExportsIn(T) {
    alias witExportsIn = AliasSeq!();

    static foreach(M; __traits(allMembers, T)) {
        static foreach(Export; __traits(getOverloads, T, M)) {
            static foreach(uda; __traits(getAttributes, Export)) {
                static if (!is(uda) && is(typeof(uda) == witExport)) {
                    witExportsIn = AliasSeq!(witExportsIn, Export);
                }
            }
        }
    }
}

// Defined by `wasi_libc`
/*
@wasmExport!("cabi_realloc")
void* cabi_realloc(void *ptr, size_t oldSize, size_t alignment, size_t newSize) {
    if (newSize == 0) return cast(void*)alignment;
    void *ret = realloc(ptr, newSize);
    if (!ret) abort();
    return ret;
}
*/
