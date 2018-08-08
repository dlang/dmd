/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/identifier.d, _identifier.d)
 * Documentation:  https://dlang.org/phobos/dmd_identifier.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/identifier.d
 */

module dmd.identifier;

import core.stdc.ctype;
import core.stdc.stdio;
import core.stdc.string;
import dmd.globals;
import dmd.id;
import dmd.root.outbuffer;
import dmd.root.rootobject;
import dmd.root.stringtable;
import dmd.tokens;
import dmd.utf;

/***********************************************************
 */
extern (C++) final class Identifier : RootObject
{
private:
    const int value;
    const char* name;
    const size_t len;

public:

    extern (D) this(const(char)* name, size_t length, int value) nothrow
    {
        //printf("Identifier('%s', %d)\n", name, value);
        this.name = name;
        this.value = value;
        this.len = length;
    }

    extern (D) this(const(char)* name) nothrow
    {
        //printf("Identifier('%s', %d)\n", name, value);
        this(name, strlen(name), TOK.identifier);
    }

    static Identifier create(const(char)* name) nothrow
    {
        return new Identifier(name);
    }

    override bool equals(RootObject o) const
    {
        return this == o || strncmp(name, o.toChars(), len + 1) == 0;
    }

    override int compare(RootObject o) const
    {
        return strncmp(name, o.toChars(), len + 1);
    }

nothrow:
    override void print() const
    {
        fprintf(stderr, "%s", name);
    }

    override const(char)* toChars() const pure
    {
        return name;
    }

    extern (D) final const(char)[] toString() const pure
    {
        return name[0 .. len];
    }

    final int getValue() const pure
    {
        return value;
    }

    const(char)* toHChars2() const
    {
        const(char)* p = null;
        if (this == Id.ctor)
            p = "this";
        else if (this == Id.dtor)
            p = "~this";
        else if (this == Id.unitTest)
            p = "unittest";
        else if (this == Id.dollar)
            p = "$";
        else if (this == Id.withSym)
            p = "with";
        else if (this == Id.result)
            p = "result";
        else if (this == Id.returnLabel)
            p = "return";
        else
        {
            p = toChars();
            if (*p == '_')
            {
                if (strncmp(p, "_staticCtor", 11) == 0)
                    p = "static this";
                else if (strncmp(p, "_staticDtor", 11) == 0)
                    p = "static ~this";
                else if (strncmp(p, "__invariant", 11) == 0)
                    p = "invariant";
            }
        }
        return p;
    }

    override DYNCAST dyncast() const
    {
        return DYNCAST.identifier;
    }

    extern (C++) __gshared StringTable stringtable;

    static Identifier generateId(const(char)* prefix)
    {
        __gshared size_t i;
        return generateId(prefix, ++i);
    }

    static Identifier generateId(const(char)* prefix, size_t i)
    {
        OutBuffer buf;
        buf.writestring(prefix);
        buf.print(i);
        return idPool(buf.peekSlice());
    }

    /***************************************
     * Generate deterministic named identifier based on a source location,
     * such that the name is consistent across multiple compilations.
     * A new unique name is generated. If the prefix+location is already in
     * the stringtable, an extra suffix is added (starting the count at "_1").
     *
     * Params:
     *      prefix      = first part of the identifier name.
     *      loc         = source location to use in the identifier name.
     * Returns:
     *      Identifier (inside Identifier.idPool) with deterministic name based
     *      on the source location.
     */
    extern (D) static Identifier generateIdWithLoc(string prefix, const ref Loc loc)
    {
        OutBuffer buf;
        buf.writestring(prefix);
        buf.writestring("_L");
        buf.print(loc.linnum);
        buf.writestring("_C");
        buf.print(loc.charnum);
        auto basesize = buf.peekSlice().length;
        uint counter = 1;
        while (stringtable.lookup(buf.peekSlice().ptr, buf.peekSlice().length) !is null)
        {
            // Strip the extra suffix
            buf.setsize(basesize);
            // Add new suffix with increased counter
            buf.writestring("_");
            buf.print(counter++);
        }
        return idPool(buf.peekSlice());
    }

    /********************************************
     * Create an identifier in the string table.
     */
    extern (D) static Identifier idPool(const(char)[] s)
    {
        return idPool(s.ptr, cast(uint)s.length);
    }

    static Identifier idPool(const(char)* s, uint len)
    {
        StringValue* sv = stringtable.update(s, len);
        Identifier id = cast(Identifier)sv.ptrvalue;
        if (!id)
        {
            id = new Identifier(sv.toDchars(), len, TOK.identifier);
            sv.ptrvalue = cast(char*)id;
        }
        return id;
    }

    extern (D) static Identifier idPool(const(char)* s, size_t len, int value)
    {
        auto sv = stringtable.insert(s, len, null);
        assert(sv);
        auto id = new Identifier(sv.toDchars(), len, value);
        sv.ptrvalue = cast(char*)id;
        return id;
    }

    /**********************************
     * Determine if string is a valid Identifier.
     * Returns:
     *      0       invalid
     */
    static bool isValidIdentifier(const(char)* p)
    {
        size_t len;
        size_t idx;
        if (!p || !*p)
            goto Linvalid;
        if (*p >= '0' && *p <= '9') // beware of isdigit() on signed chars
            goto Linvalid;
        len = strlen(p);
        idx = 0;
        while (p[idx])
        {
            dchar dc;
            const q = utf_decodeChar(p, len, idx, dc);
            if (q)
                goto Linvalid;
            if (!((dc >= 0x80 && isUniAlpha(dc)) || isalnum(dc) || dc == '_'))
                goto Linvalid;
        }
        return true;
    Linvalid:
        return false;
    }

    static Identifier lookup(const(char)* s, size_t len)
    {
        auto sv = stringtable.lookup(s, len);
        if (!sv)
            return null;
        return cast(Identifier)sv.ptrvalue;
    }

    static void initTable()
    {
        stringtable._init(28000);
    }
}
