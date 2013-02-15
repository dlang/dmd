/**
 * Runtime support for dynamic libraries.
 *
 * Copyright: Copyright Martin Nowak 2012-2013.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Martin Nowak
 * Source: $(DRUNTIMESRC src/rt/_dso.d)
 */
module rt.dso;

version (Windows)
{
    // missing integration with the existing DLL mechanism
    enum USE_DSO = false;
}
else version (linux)
{
    enum USE_DSO = true;
}
else version (OSX)
{
    // missing integration with rt.memory_osx.onAddImage
    enum USE_DSO = false;
}
else version (FreeBSD)
{
    // missing elf and link headers
    enum USE_DSO = false;
}
else
{
    static assert(0, "Unsupported platform");
}

static if (USE_DSO) // '{}' instead of ':' => Bugzilla 8898
{

import rt.minfo;
import rt.deh2;
import rt.util.container;
import core.stdc.stdlib;

struct DSO
{
    static int opApply(scope int delegate(ref DSO) dg)
    {
        foreach(dso; _static_dsos)
        {
            if (auto res = dg(*dso))
                return res;
        }
        return 0;
    }

    static int opApplyReverse(scope int delegate(ref DSO) dg)
    {
        foreach_reverse(dso; _static_dsos)
        {
            if (auto res = dg(*dso))
                return res;
        }
        return 0;
    }

    @property inout(ModuleInfo*)[] modules() inout
    {
        return _moduleGroup.modules;
    }

    @property ref inout(ModuleGroup) moduleGroup() inout
    {
        return _moduleGroup;
    }

    @property inout(FuncTable)[] ehtables() inout
    {
        return _ehtables[];
    }

private:

    invariant()
    {
        assert(_moduleGroup.modules.length);
    }

    FuncTable[]     _ehtables;
    ModuleGroup  _moduleGroup;
}

private:

/*
 * Static DSOs loaded by the runtime linker. This includes the
 * executable. These can't be unloaded.
 */
__gshared Array!(DSO*) _static_dsos;


///////////////////////////////////////////////////////////////////////////////
// Compiler to runtime interface.
///////////////////////////////////////////////////////////////////////////////


/*
 *
 */
struct CompilerDSOData
{
    size_t _version;
    void** _slot; // can be used to store runtime data
    object.ModuleInfo** _minfo_beg, _minfo_end;
    rt.deh2.FuncTable* _deh_beg, _deh_end;
}

T[] toRange(T)(T* beg, T* end) { return beg[0 .. end - beg]; }

extern(C) void _d_dso_registry(CompilerDSOData* data)
{
    // only one supported currently
    data._version >= 1 || assert(0, "corrupt DSO data version");

    // no backlink => register
    if (*data._slot is null)
    {
        DSO* pdso = cast(DSO*).calloc(1, DSO.sizeof);
        assert(typeid(DSO).init().ptr is null);
        *data._slot = pdso; // store backlink in library record

        pdso._moduleGroup = ModuleGroup(toRange(data._minfo_beg, data._minfo_end));
        pdso._ehtables = toRange(data._deh_beg, data._deh_end);

        _static_dsos.insertBack(pdso);
    }
    // has backlink => unregister
    else
    {
        DSO* pdso = cast(DSO*)*data._slot;
        assert(pdso == _static_dsos.back); // DSOs are unloaded in reverse order
        _static_dsos.popBack();

        *data._slot = null;
        .free(pdso);
    }
}
}
