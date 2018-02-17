/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/objc.d, _objc.d)
 * Documentation:  https://dlang.org/phobos/dmd_objc.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/objc.d
 */

module dmd.objc;

import dmd.arraytypes;
import dmd.cond;
import dmd.dclass;
import dmd.dmangle;
import dmd.dmodule;
import dmd.dscope;
import dmd.dstruct;
import dmd.expression;
import dmd.func;
import dmd.globals;
import dmd.gluelayer;
import dmd.id;
import dmd.identifier;
import dmd.mtype;
import dmd.root.outbuffer;
import dmd.root.stringtable;

struct ObjcSelector
{
    // MARK: Selector
    extern (C++) static __gshared StringTable stringtable;
    extern (C++) static __gshared StringTable vTableDispatchSelectors;
    extern (C++) static __gshared int incnum = 0;
    const(char)* stringvalue;
    size_t stringlen;
    size_t paramCount;

    extern (C++) static void _init()
    {
        stringtable._init();
    }

    extern (D) this(const(char)* sv, size_t len, size_t pcount)
    {
        stringvalue = sv;
        stringlen = len;
        paramCount = pcount;
    }

    extern (C++) static ObjcSelector* lookup(const(char)* s)
    {
        size_t len = 0;
        size_t pcount = 0;
        const(char)* i = s;
        while (*i != 0)
        {
            ++len;
            if (*i == ':')
                ++pcount;
            ++i;
        }
        return lookup(s, len, pcount);
    }

    extern (C++) static ObjcSelector* lookup(const(char)* s, size_t len, size_t pcount)
    {
        StringValue* sv = stringtable.update(s, len);
        ObjcSelector* sel = cast(ObjcSelector*)sv.ptrvalue;
        if (!sel)
        {
            sel = new ObjcSelector(sv.toDchars(), len, pcount);
            sv.ptrvalue = cast(char*)sel;
        }
        return sel;
    }

    extern (C++) static ObjcSelector* create(FuncDeclaration fdecl)
    {
        OutBuffer buf;
        size_t pcount = 0;
        TypeFunction ftype = cast(TypeFunction)fdecl.type;
        const id = fdecl.ident.toString();
        // Special case: property setter
        if (ftype.isproperty && ftype.parameters && ftype.parameters.dim == 1)
        {
            // rewrite "identifier" as "setIdentifier"
            char firstChar = id[0];
            if (firstChar >= 'a' && firstChar <= 'z')
                firstChar = cast(char)(firstChar - 'a' + 'A');
            buf.writestring("set");
            buf.writeByte(firstChar);
            buf.write(id.ptr + 1, id.length - 1);
            buf.writeByte(':');
            goto Lcomplete;
        }
        // write identifier in selector
        buf.write(id.ptr, id.length);
        // add mangled type and colon for each parameter
        if (ftype.parameters && ftype.parameters.dim)
        {
            buf.writeByte('_');
            Parameters* arguments = ftype.parameters;
            size_t dim = Parameter.dim(arguments);
            for (size_t i = 0; i < dim; i++)
            {
                Parameter arg = Parameter.getNth(arguments, i);
                mangleToBuffer(arg.type, &buf);
                buf.writeByte(':');
            }
            pcount = dim;
        }
    Lcomplete:
        buf.writeByte('\0');
        return lookup(cast(const(char)*)buf.data, buf.size, pcount);
    }

    extern (D) final const(char)[] toString() const pure
    {
        return stringvalue[0 .. stringlen];
    }
}

private __gshared Objc _objc;

Objc objc()
{
    return _objc;
}

// Should be an interface
extern(C++) abstract class Objc
{
    static void _init()
    {
        if (global.params.isOSX && global.params.is64bit)
            _objc = new Supported;
        else
            _objc = new Unsupported;
    }

    abstract void setObjc(ClassDeclaration cd);
    abstract void setObjc(InterfaceDeclaration);
    abstract void setSelector(FuncDeclaration, Scope* sc);
    abstract void validateSelector(FuncDeclaration fd);
    abstract void checkLinkage(FuncDeclaration fd);
}

extern(C++) private final class Unsupported : Objc
{
    extern(D) final this()
    {
        ObjcGlue.initialize();
    }

    override void setObjc(ClassDeclaration cd)
    {
        cd.error("Objective-C classes not supported");
    }

    override void setObjc(InterfaceDeclaration id)
    {
        id.error("Objective-C interfaces not supported");
    }

    override void setSelector(FuncDeclaration, Scope*)
    {
        // noop
    }

    override void validateSelector(FuncDeclaration)
    {
        // noop
    }

    override void checkLinkage(FuncDeclaration)
    {
        // noop
    }
}

extern(C++) private final class Supported : Objc
{
    extern(D) final this()
    {
        VersionCondition.addPredefinedGlobalIdent("D_ObjectiveC");

        ObjcGlue.initialize();
        ObjcSelector._init();
    }

    override void setObjc(ClassDeclaration cd)
    {
        cd.classKind = ClassKind.objc;
    }

    override void setObjc(InterfaceDeclaration id)
    {
        id.classKind = ClassKind.objc;
    }

    override void setSelector(FuncDeclaration fd, Scope* sc)
    {
        import dmd.tokens;

        if (!fd.userAttribDecl)
            return;
        Expressions* udas = fd.userAttribDecl.getAttributes();
        arrayExpressionSemantic(udas, sc, true);
        for (size_t i = 0; i < udas.dim; i++)
        {
            Expression uda = (*udas)[i];
            assert(uda);
            if (uda.op != TOK.tuple)
                continue;
            Expressions* exps = (cast(TupleExp)uda).exps;
            for (size_t j = 0; j < exps.dim; j++)
            {
                Expression e = (*exps)[j];
                assert(e);
                if (e.op != TOK.structLiteral)
                    continue;
                StructLiteralExp literal = cast(StructLiteralExp)e;
                assert(literal.sd);
                if (!isUdaSelector(literal.sd))
                    continue;
                if (fd.selector)
                {
                    fd.error("can only have one Objective-C selector per method");
                    return;
                }
                assert(literal.elements.dim == 1);
                StringExp se = (*literal.elements)[0].toStringExp();
                assert(se);
                fd.selector = ObjcSelector.lookup(cast(const(char)*)se.toUTF8(sc).string);
            }
        }
    }

    override void validateSelector(FuncDeclaration fd)
    {
        if (!fd.selector)
            return;
        TypeFunction tf = cast(TypeFunction)fd.type;
        if (fd.selector.paramCount != tf.parameters.dim)
            fd.error("number of colons in Objective-C selector must match number of parameters");
        if (fd.parent && fd.parent.isTemplateInstance())
            fd.error("template cannot have an Objective-C selector attached");
    }

    override void checkLinkage(FuncDeclaration fd)
    {
        if (fd.linkage != LINK.objc && fd.selector)
            fd.error("must have Objective-C linkage to attach a selector");
    }

    extern(D) private bool isUdaSelector(StructDeclaration sd)
    {
        if (sd.ident != Id.udaSelector || !sd.parent)
            return false;
        Module _module = sd.parent.isModule();
        return _module && _module.isCoreModule(Id.attribute);
    }
}
