/**
 * Convert a D type to a type the backend understands.
 *
 * Copyright:   Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/toctype.d, _toctype.d)
 * Documentation:  https://dlang.org/phobos/dmd_toctype.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/toctype.d
 */

module dmd.toctype;

import core.stdc.stdio;
import core.stdc.stdlib;

import dmd.backend.cc : Classsym, Symbol;
import dmd.backend.ty;
import dmd.backend.type;

import dmd.root.rmem;

import dmd.astenums;
import dmd.declaration;
import dmd.denum;
import dmd.dstruct;
import dmd.globals;
import dmd.glue;
import dmd.id;
import dmd.mtype;
import dmd.tocvdebug;
import dmd.visitor;


/*******************
 * Determine backend tym bits corresponding to MOD
 * Params:
 *  mod = mod bits
 * Returns:
 *  corresponding tym_t bits
 */
tym_t modToTym(MOD mod) pure
{
    switch (mod)
    {
        case 0:
            return 0;

        case MODFlags.const_:
        case MODFlags.wild:
        case MODFlags.wildconst:
            return mTYconst;

        case MODFlags.shared_:
            return mTYshared;

        case MODFlags.shared_ | MODFlags.const_:
        case MODFlags.shared_ | MODFlags.wild:
        case MODFlags.shared_ | MODFlags.wildconst:
            return mTYshared | mTYconst;

        case MODFlags.immutable_:
            return mTYimmutable;

        default:
            assert(0);
    }
}


/************************************
 * Convert front end type `t` to backend type `t.ctype`.
 * Memoize the result.
 * Params:
 *      t = front end `Type`
 * Returns:
 *      back end equivalent `type`
 */
extern (C++) type* Type_toCtype(Type t)
{
    if (!t.ctype)
    {
        scope ToCtypeVisitor v = new ToCtypeVisitor();
        t.accept(v);
    }
    return t.ctype;
}

private extern (C++) final class ToCtypeVisitor : Visitor
{
    alias visit = Visitor.visit;
public:
    extern (D) this()
    {
    }

    override void visit(Type t)
    {
        t.ctype = type_fake(totym(t));
        t.ctype.Tcount++;
    }

    override void visit(TypeSArray t)
    {
        t.ctype = type_static_array(t.dim.toInteger(), Type_toCtype(t.next));
    }

    override void visit(TypeDArray t)
    {
        t.ctype = type_dyn_array(Type_toCtype(t.next));
        t.ctype.Tident = t.toPrettyChars(true);
    }

    override void visit(TypeAArray t)
    {
        t.ctype = type_assoc_array(Type_toCtype(t.index), Type_toCtype(t.next));
        t.ctype.Tident = t.toPrettyChars(true);
    }

    override void visit(TypePointer t)
    {
        //printf("TypePointer::toCtype() %s\n", t.toChars());
        t.ctype = type_pointer(Type_toCtype(t.next));
    }

    override void visit(TypeFunction t)
    {
        const nparams = t.parameterList.length;
        type*[10] tmp = void;
        type** ptypes = (nparams <= tmp.length)
                        ? tmp.ptr
                        : cast(type**)Mem.check(malloc((type*).sizeof * nparams));
        type*[] types = ptypes[0 .. nparams];

        foreach (i; 0 .. nparams)
        {
            Parameter p = t.parameterList[i];
            type* tp = Type_toCtype(p.type);
            if (p.isReference())
                tp = type_allocn(TYnref, tp);
            else if (p.storageClass & STC.lazy_)
            {
                // Mangle as delegate
                type* tf = type_function(TYnfunc, null, false, tp);
                tp = type_delegate(tf);
            }
            types[i] = tp;
        }
        t.ctype = type_function(totym(t), types, t.parameterList.varargs == VarArg.variadic, Type_toCtype(t.next));
        if (types.ptr != tmp.ptr)
            free(types.ptr);
    }

    override void visit(TypeDelegate t)
    {
        t.ctype = type_delegate(Type_toCtype(t.next));
    }

    override void visit(TypeStruct t)
    {
        //printf("TypeStruct::toCtype() '%s'\n", t.sym.toChars());
        if (t.mod == 0)
        {
            // Create a new backend type
            StructDeclaration sym = t.sym;
            auto arg1type = sym.argType(0);
            auto arg2type = sym.argType(1);
            t.ctype = type_struct_class(sym.toPrettyChars(true), sym.alignsize, sym.structsize, arg1type ? Type_toCtype(arg1type) : null, arg2type ? Type_toCtype(arg2type) : null, sym.isUnionDeclaration() !is null, false, sym.isPOD() != 0, sym.hasNoFields);
            /* Add in fields of the struct
             * (after setting ctype to avoid infinite recursion)
             */
            if (global.params.symdebug && !global.errors)
            {
                foreach (v; sym.fields)
                {
                    symbol_struct_addField(cast(Symbol*)t.ctype.Ttag, v.ident.toChars(), Type_toCtype(v.type), v.offset);
                }
            }

            if (global.params.symdebugref)
                toDebug(sym);

            return;
        }

        // Copy mutable version of backend type and add modifiers
        type* mctype = Type_toCtype(t.castMod(0));
        t.ctype = type_alloc(tybasic(mctype.Tty));
        t.ctype.Tcount++;
        if (t.ctype.Tty == TYstruct)
        {
            t.ctype.Ttag = mctype.Ttag; // structure tag name
        }
        t.ctype.Tty |= modToTym(t.mod);
        //printf("t = %p, Tflags = x%x\n", ctype, ctype.Tflags);
    }

    override void visit(TypeEnum t)
    {
        //printf("TypeEnum::toCtype() '%s'\n", t.sym.toChars());
        if (t.mod == 0)
        {
            EnumDeclaration sym = t.sym;
            auto symMemtype = sym.memtype;
            if (!symMemtype)
            {
                // https://issues.dlang.org/show_bug.cgi?id=13792
                t.ctype = Type_toCtype(Type.tvoid);
            }
            else if (sym.ident == Id.__c_long ||
                     sym.ident == Id.__c_complex_float ||
                     sym.ident == Id.__c_complex_double ||
                     sym.ident == Id.__c_complex_real)
            {
                t.ctype = type_fake(totym(t));
                t.ctype.Tcount++;
                return;
            }
            else if (symMemtype.toBasetype().ty == Tint32)
            {
                t.ctype = type_enum(sym.toPrettyChars(true), Type_toCtype(symMemtype));
            }
            else
            {
                t.ctype = Type_toCtype(symMemtype);
            }

            if (global.params.symdebugref)
                toDebug(t.sym);

            return;
        }

        // Copy mutable version of backend type and add modifiers
        type* mctype = Type_toCtype(t.castMod(0));
        if (tybasic(mctype.Tty) == TYenum)
        {
            Classsym* s = mctype.Ttag;
            assert(s);
            t.ctype = type_allocn(TYenum, mctype.Tnext);
            t.ctype.Ttag = s; // enum tag name
            t.ctype.Tcount++;
            t.ctype.Tty |= modToTym(t.mod);
        }
        else
            t.ctype = mctype;

        //printf("t = %p, Tflags = x%x\n", t, t.Tflags);
    }

    override void visit(TypeClass t)
    {
        if (t.mod == 0)
        {
            //printf("TypeClass::toCtype() %s\n", toChars());
            type* tc = type_struct_class(t.sym.toPrettyChars(true), t.sym.alignsize, t.sym.structsize, null, null, false, true, true, false);
            t.ctype = type_pointer(tc);
            /* Add in fields of the class
             * (after setting ctype to avoid infinite recursion)
             */
            if (global.params.symdebug)
            {
                foreach (v; t.sym.fields)
                {
                    symbol_struct_addField(cast(Symbol*)tc.Ttag, v.ident.toChars(), Type_toCtype(v.type), v.offset);
                }
            }

            if (global.params.symdebugref)
                toDebug(t.sym);
            return;
        }

        // Copy mutable version of backend type and add modifiers
        type* mctype = Type_toCtype(t.castMod(0));
        t.ctype = type_allocn(tybasic(mctype.Tty), mctype.Tnext); // pointer to class instance
        t.ctype.Tcount++;
        t.ctype.Tty |= modToTym(t.mod);
    }
}
