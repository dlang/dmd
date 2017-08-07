/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _toctype.d)
 */

module ddmd.toctype;

import core.stdc.stdlib;

import ddmd.backend.cc : Classsym, Symbol;
import ddmd.backend.ty;
import ddmd.backend.type;

import ddmd.declaration;
import ddmd.dstruct;
import ddmd.globals;
import ddmd.glue;
import ddmd.id;
import ddmd.mtype;
import ddmd.tocvdebug;
import ddmd.visitor;

extern (C++) final class ToCtypeVisitor : Visitor
{
    alias visit = super.visit;
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
    }

    override void visit(TypePointer t)
    {
        //printf("TypePointer::toCtype() %s\n", t.toChars());
        t.ctype = type_pointer(Type_toCtype(t.next));
    }

    override void visit(TypeFunction t)
    {
        size_t nparams = Parameter.dim(t.parameters);
        type*[10] tmp;
        type** ptypes = tmp.ptr;
        if (nparams > 10)
            ptypes = cast(type**)malloc((type*).sizeof * nparams);
        for (size_t i = 0; i < nparams; i++)
        {
            Parameter p = Parameter.getNth(t.parameters, i);
            type* tp = Type_toCtype(p.type);
            if (p.storageClass & (STCout | STCref))
                tp = type_allocn(TYnref, tp);
            else if (p.storageClass & STClazy)
            {
                // Mangle as delegate
                type* tf = type_function(TYnfunc, null, 0, false, tp);
                tp = type_delegate(tf);
            }
            ptypes[i] = tp;
        }
        t.ctype = type_function(totym(t), ptypes, nparams, t.varargs == 1, Type_toCtype(t.next));
        if (nparams > 10)
            free(ptypes);
    }

    override void visit(TypeDelegate t)
    {
        t.ctype = type_delegate(Type_toCtype(t.next));
    }

    void addMod(Type t)
    {
        switch (t.mod)
        {
        case 0:
            assert(0);
        case MODconst:
        case MODwild:
        case MODwildconst:
            t.ctype.Tty |= mTYconst;
            break;
        case MODshared:
            t.ctype.Tty |= mTYshared;
            break;
        case MODshared | MODconst:
        case MODshared | MODwild:
        case MODshared | MODwildconst:
            t.ctype.Tty |= mTYshared | mTYconst;
            break;
        case MODimmutable:
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
            if (sym.ident == Id.__c_long_double)
            {
                t.ctype = type_fake(TYdouble);
                t.ctype.Tcount++;
                return;
            }
            t.ctype = type_struct_class(sym.toPrettyChars(true), sym.alignsize, sym.structsize, sym.arg1type ? Type_toCtype(sym.arg1type) : null, sym.arg2type ? Type_toCtype(sym.arg2type) : null, sym.isUnionDeclaration() !is null, false, sym.isPOD() != 0);
            /* Add in fields of the struct
             * (after setting ctype to avoid infinite recursion)
             */
            if (global.params.symdebug)
            {
                for (size_t i = 0; i < sym.fields.dim; i++)
                {
                    VarDeclaration v = sym.fields[i];
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
            if (!t.sym.memtype)
            {
                // https://issues.dlang.org/show_bug.cgi?id=13792
                t.ctype = Type_toCtype(Type.tvoid);
            }
            else if (t.sym.memtype.toBasetype().ty == Tint32)
            {
                t.ctype = type_enum(t.sym.toPrettyChars(true), Type_toCtype(t.sym.memtype));
            }
            else
            {
                t.ctype = Type_toCtype(t.sym.memtype);
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
            t.ctype = type_alloc(TYenum);
            t.ctype.Ttag = s; // enum tag name
            t.ctype.Tcount++;
            t.ctype.Tnext = mctype.Tnext;
            t.ctype.Tnext.Tcount++;
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
            type* tc = type_struct_class(t.sym.toPrettyChars(true), t.sym.alignsize, t.sym.structsize, null, null, false, true, true);
            t.ctype = type_pointer(tc);
            /* Add in fields of the class
             * (after setting ctype to avoid infinite recursion)
             */
            if (global.params.symdebug)
            {
                for (size_t i = 0; i < t.sym.fields.dim; i++)
                {
                    VarDeclaration v = t.sym.fields[i];
                    symbol_struct_addField(cast(Symbol*)tc.Ttag, v.ident.toChars(), Type_toCtype(v.type), v.offset);
                }
            }

            if (global.params.symdebugref)
                toDebug(t.sym);
            return;
        }

        // Copy mutable version of backend type and add modifiers
        type* mctype = Type_toCtype(t.castMod(0));
        t.ctype = type_alloc(tybasic(mctype.Tty)); // pointer to class instance
        t.ctype.Tcount++;
        addMod(t);
    }
}

extern (C++) type* Type_toCtype(Type t)
{
    if (!t.ctype)
    {
        scope ToCtypeVisitor v = new ToCtypeVisitor();
        t.accept(v);
    }
    return t.ctype;
}
