// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.identifier;

import core.stdc.ctype;
import core.stdc.stdio;
import core.stdc.string;
import ddmd.globals;
import ddmd.id;
import ddmd.root.outbuffer;
import ddmd.root.rootobject;
import ddmd.root.stringtable;
import ddmd.tokens;
import ddmd.utf;

/***********************************************************
 */
extern (C++) final class Identifier : RootObject
{
public:
    int value;
    const(char)* string;
    size_t len;

    extern (D) this(const(char)* string, int value)
    {
        //printf("Identifier('%s', %d)\n", string, value);
        this.string = string;
        this.value = value;
        this.len = strlen(string);
    }

    static Identifier create(const(char)* string, int value)
    {
        return new Identifier(string, value);
    }

    override bool equals(RootObject o)
    {
        return this == o || strncmp(string, o.toChars(), len + 1) == 0;
    }

    override int compare(RootObject o)
    {
        return strncmp(string, o.toChars(), len + 1);
    }

    override void print()
    {
        fprintf(stderr, "%s", string);
    }

    override char* toChars()
    {
        return cast(char*)string;
    }

    const(char)* toHChars2()
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

    override int dyncast()
    {
        return DYNCAST_IDENTIFIER;
    }

    extern (C++) static __gshared StringTable stringtable;

    static Identifier generateId(const(char)* prefix)
    {
        static __gshared size_t i;
        return generateId(prefix, ++i);
    }

    static Identifier generateId(const(char)* prefix, size_t i)
    {
        OutBuffer buf;
        buf.writestring(prefix);
        buf.printf("%llu", cast(ulong)i);
        char* id = buf.peekString();
        return idPool(id);
    }

    /********************************************
     * Create an identifier in the string table.
     */
    static Identifier idPool(const(char)* s)
    {
        return idPool(s, strlen(s));
    }

    static Identifier idPool(const(char)* s, size_t len)
    {
        StringValue* sv = stringtable.update(s, len);
        Identifier id = cast(Identifier)sv.ptrvalue;
        if (!id)
        {
            id = new Identifier(sv.toDchars(), TOKidentifier);
            sv.ptrvalue = cast(char*)id;
        }
        return id;
    }

    /**********************************
     * Determine if string is a valid Identifier.
     * Returns:
     *      0       invalid
     */
    final static bool isValidIdentifier(const(char)* p)
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
            dchar_t dc;
            const(char)* q = utf_decodeChar(cast(char*)p, len, &idx, &dc);
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
        StringValue* sv = stringtable.lookup(s, len);
        if (!sv)
            return null;
        return cast(Identifier)sv.ptrvalue;
    }

    static void initTable()
    {
        stringtable._init(28000);
    }
}
