/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2019 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/toctype.d, _toctype.d)
 * Documentation:  https://dlang.org/phobos/dmd_toctype.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/toctype.d
 */

module dmd.toctype;

import core.stdc.stdlib;

import dmd.backend.cc : Classsym, Symbol;
import dmd.backend.ty;
import dmd.backend.type;

import dmd.declaration;
import dmd.denum;
import dmd.dstruct;
import dmd.globals;
import dmd.glue;
import dmd.id;
import dmd.mtype;
import dmd.tocvdebug;
import dmd.visitor;


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
                        : cast(type**)malloc((type*).sizeof * nparams);
        assert(ptypes);
        type*[] types = ptypes[0 .. nparams];

        foreach (i; 0 .. nparams)
        {
            Parameter p = t.parameterList[i];
            type* tp = Type_toCtype(p.type);
            if (p.storageClass & (STC.out_ | STC.ref_))
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

    /*******************
     * Add D modification bits for `Type t` to the corresponding backend type `t.ctype`
     * Params:
     *  t = front end Type
     */
    static void addMod(Type t)
    {
        switch (t.mod)
        {
        case 0:
            assert(0);
        case MODFlags.const_:
        case MODFlags.wild:
        case MODFlags.wildconst:
            t.ctype.Tty |= mTYconst;
            break;
        case MODFlags.shared_:
            t.ctype.Tty |= mTYshared;
            break;
        case MODFlags.shared_ | MODFlags.const_:
        case MODFlags.shared_ | MODFlags.wild:
        case MODFlags.shared_ | MODFlags.wildconst:
            t.ctype.Tty |= mTYshared | mTYconst;
            break;
        case MODFlags.immutable_:
            t.ctype.Tty |= mTYimmutable;
            break;
        default:
            assert(0);
        }
    }

    override void visit(TypeStruct t)
    {
        //printf("TypeStruct::toCtype() '%s'\n", t.sym.toChars());
        if (t.mod == 0)
        {
            // Create a new backend type
            StructDeclaration sym = t.sym;
            t.ctype = type_struct_class(sym.toPrettyChars(true), sym.alignsize, sym.structsize, sym.arg1type ? Type_toCtype(sym.arg1type) : null, sym.arg2type ? Type_toCtype(sym.arg2type) : null, sym.isUnionDeclaration() !is null, false, sym.isPOD() != 0, sym.hasNoFields);
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
        addMod(t);
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
            else if (sym.ident == Id.__c_long)
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
            addMod(t);
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
        addMod(t);
    }
}
