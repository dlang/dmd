// Compiler implementation of the D programming language
// Copyright (c) 1999-2016 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.toctype;

import core.stdc.stdlib;

import ddmd.backend;
import ddmd.declaration;
import ddmd.dstruct;
import ddmd.globals;
import ddmd.id;
import ddmd.mtype;
import ddmd.root.aav;
import ddmd.visitor;

extern extern (C++) uint totym(Type tx);

extern (C++) final class ToCtypeVisitor : Visitor
{
    __gshared static AA *ctypeMap;
    alias visit = super.visit;
    type* ctype;
public:
    extern (D) this()
    {
    }

    override void visit(Type t)
    {
        ctype = type_fake(totym(t));
        ctype.Tcount++;
    }

    override void visit(TypeSArray t)
    {
        ctype = type_static_array(t.dim.toInteger(), Type_toCtype(t.next));
    }

    override void visit(TypeDArray t)
    {
        ctype = type_dyn_array(Type_toCtype(t.next));
        ctype.Tident = t.toPrettyChars(true);
    }

    override void visit(TypeAArray t)
    {
        ctype = type_assoc_array(Type_toCtype(t.index), Type_toCtype(t.next));
    }

    override void visit(TypePointer t)
    {
        //printf("TypePointer::toCtype() %s\n", t->toChars());
        ctype = type_pointer(Type_toCtype(t.next));
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
        ctype = type_function(totym(t), ptypes, nparams, t.varargs == 1, Type_toCtype(t.next));
        if (nparams > 10)
            free(ptypes);
    }

    override void visit(TypeDelegate t)
    {
        ctype = type_delegate(Type_toCtype(t.next));
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
            ctype.Tty |= mTYconst;
            break;
        case MODshared:
            ctype.Tty |= mTYshared;
            break;
        case MODshared | MODconst:
        case MODshared | MODwild:
        case MODshared | MODwildconst:
            ctype.Tty |= mTYshared | mTYconst;
            break;
        case MODimmutable:
            ctype.Tty |= mTYimmutable;
            break;
        default:
            assert(0);
        }
    }

    override void visit(TypeStruct t)
    {
        //printf("TypeStruct::toCtype() '%s'\n", t->sym->toChars());
        if (t.mod == 0)
        {
            // Create a new backend type
            StructDeclaration sym = t.sym;
            if (sym.ident == Id.__c_long_double)
            {
                ctype = type_fake(TYdouble);
                ctype.Tcount++;
                return;
            }
            ctype = type_struct_class(sym.toPrettyChars(true), sym.alignsize, sym.structsize, sym.arg1type ? Type_toCtype(sym.arg1type) : null, sym.arg2type ? Type_toCtype(sym.arg2type) : null, sym.isUnionDeclaration() !is null, false, sym.isPOD() != 0);
            /* Add in fields of the struct
             * (after setting ctype to avoid infinite recursion)
             */
            if (global.params.symdebug)
            {
                setCtype(t, ctype);

                for (size_t i = 0; i < sym.fields.dim; i++)
                {
                    VarDeclaration v = sym.fields[i];
                    symbol_struct_addField(cast(Symbol*)ctype.Ttag, v.ident.toChars(), Type_toCtype(v.type), v.offset);
                }
            }
            return;
        }

        // Copy mutable version of backend type and add modifiers
        type* mctype = Type_toCtype(t.castMod(0));
        ctype = type_alloc(tybasic(mctype.Tty));
        ctype.Tcount++;
        if (ctype.Tty == TYstruct)
        {
            ctype.Ttag = mctype.Ttag; // structure tag name
        }
        addMod(t);
        //printf("t = %p, Tflags = x%x\n", ctype, ctype->Tflags);
    }

    override void visit(TypeEnum t)
    {
        //printf("TypeEnum::toCtype() '%s'\n", t->sym->toChars());
        if (t.mod == 0)
        {
            if (!t.sym.memtype)
            {
                // Bugzilla 13792
                ctype = Type_toCtype(Type.tvoid);
            }
            else if (t.sym.memtype.toBasetype().ty == Tint32)
            {
                ctype = type_enum(t.sym.toPrettyChars(true), Type_toCtype(t.sym.memtype));
            }
            else
            {
                ctype = Type_toCtype(t.sym.memtype);
            }
            return;
        }

        // Copy mutable version of backend type and add modifiers
        type* mctype = Type_toCtype(t.castMod(0));
        if (tybasic(mctype.Tty) == TYenum)
        {
            Classsym* s = mctype.Ttag;
            assert(s);
            ctype = type_alloc(TYenum);
            ctype.Ttag = s; // enum tag name
            ctype.Tcount++;
            ctype.Tnext = mctype.Tnext;
            ctype.Tnext.Tcount++;
            addMod(t);
        }
        else
            ctype = mctype;
        //printf("t = %p, Tflags = x%x\n", t, t->Tflags);
    }

    override void visit(TypeClass t)
    {
        //printf("TypeClass::toCtype() %s\n", toChars());
        type* tc = type_struct_class(t.sym.toPrettyChars(true), t.sym.alignsize, t.sym.structsize, null, null, false, true, true);
        ctype = type_pointer(tc);
        /* Add in fields of the class
         * (after setting ctype to avoid infinite recursion)
         */
        if (global.params.symdebug)
        {
            setCtype(t, ctype);

            for (size_t i = 0; i < t.sym.fields.dim; i++)
            {
                VarDeclaration v = t.sym.fields[i];
                symbol_struct_addField(cast(Symbol*)tc.Ttag, v.ident.toChars(), Type_toCtype(v.type), v.offset);
            }
        }
    }

    static void setCtype(Type t, type* ctype)
    {
        auto pctype = cast(type**)dmd_aaGet(&ctypeMap, cast(void*)t);
        *pctype = ctype;
    }

    static type *toCtype(Type t)
    {
        auto pctype = cast(type**)dmd_aaGet(&ctypeMap, cast(void*)t);

        if (!*pctype)
        {
            scope v = new ToCtypeVisitor();
            t.accept(v);
            *pctype = v.ctype;
        }
        return *pctype;
    }
}

extern (C++) type* Type_toCtype(Type t)
{
    return ToCtypeVisitor.toCtype(t);
}
