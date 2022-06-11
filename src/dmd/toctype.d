/**
 * Convert a D type to a type the backend understands.
 *
 * Copyright:   Copyright (C) 1999-2022 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
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
import dmd.dmdparams;
import dmd.dstruct;
import dmd.globals;
import dmd.glue;
import dmd.id;
import dmd.mtype;
import dmd.tocvdebug;


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
    if (t.ctype)
        return t.ctype;

    static type* visit(Type t)
    {
        type* tr = type_fake(totym(t));
        tr.Tcount++;
        return tr;
    }

    static type* visitSArray(TypeSArray t)
    {
        auto ta = type_static_array(t.dim.toInteger(), Type_toCtype(t.next));
        ta.Tty |= ta.Tnext.Tty & mTYconst;
        return ta;
    }

    static type* visitDArray(TypeDArray t)
    {
        type* tr = type_dyn_array(Type_toCtype(t.next));
        tr.Tident = t.toPrettyChars(true);
        return tr;
    }

    static type* visitAArray(TypeAArray t)
    {
        type* tr = type_assoc_array(Type_toCtype(t.index), Type_toCtype(t.next));
        tr.Tident = t.toPrettyChars(true);
        return tr;
    }

    static type* visitPointer(TypePointer t)
    {
        //printf("TypePointer::toCtype() %s\n", t.toChars());
        return type_pointer(Type_toCtype(t.next));
    }

    static type* visitFunction(TypeFunction t)
    {
        const nparams = t.parameterList.length;
        import dmd.common.string : SmallBuffer;
        type*[10] tmp = void;
        auto sb = SmallBuffer!(type*)(nparams, tmp[]);
        type*[] types = sb[];

        foreach (i; 0 .. nparams)
        {
            Parameter p = t.parameterList[i];
            type* tp = Type_toCtype(p.type);
            if (p.isReference())
                tp = type_allocn(TYnref, tp);
            else if (p.isLazy())
            {
                // Mangle as delegate
                type* tf = type_function(TYnfunc, null, false, tp);
                tp = type_delegate(tf);
                tp.Tident = t.toPrettyChars(true);
            }
            types[i] = tp;
        }
        return type_function(totym(t), types, t.parameterList.varargs == VarArg.variadic, Type_toCtype(t.next));
    }

    static type* visitDelegate(TypeDelegate t)
    {
        type* tr = type_delegate(Type_toCtype(t.next));
        tr.Tident = t.toPrettyChars(true);
        return tr;
    }

    static type* visitStruct(TypeStruct t)
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
            if (driverParams.symdebug && !global.errors)
            {
                foreach (v; sym.fields)
                {
                    if (auto bf = v.isBitFieldDeclaration())
                        symbol_struct_addBitField(cast(Symbol*)t.ctype.Ttag, v.ident.toChars(), Type_toCtype(v.type), v.offset, bf.fieldWidth, bf.bitOffset);
                    else
                        symbol_struct_addField(cast(Symbol*)t.ctype.Ttag, v.ident.toChars(), Type_toCtype(v.type), v.offset);
                }
            }
            else
            {
                foreach (v; sym.fields)
                {
                    if (auto bf = v.isBitFieldDeclaration())
                    {
                        symbol_struct_hasBitFields(cast(Symbol*)t.ctype.Ttag);
                        break;
                    }
                }
            }

            if (driverParams.symdebugref)
                toDebug(sym);

            return t.ctype;
        }

        // Copy mutable version of backend type and add modifiers
        type* mctype = Type_toCtype(t.castMod(0));
        type* tr = type_alloc(tybasic(mctype.Tty));
        tr.Tcount++;
        if (tr.Tty == TYstruct)
        {
            tr.Ttag = mctype.Ttag; // structure tag name
        }
        tr.Tty |= modToTym(t.mod);
        //printf("t = %p, Tflags = x%x\n", ctype, ctype.Tflags);
        return tr;
    }

    static type* visitEnum(TypeEnum t)
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
                return t.ctype;
            }
            else if (symMemtype.toBasetype().ty == Tint32)
            {
                t.ctype = type_enum(sym.toPrettyChars(true), Type_toCtype(symMemtype));
            }
            else
            {
                t.ctype = Type_toCtype(symMemtype);
            }

            if (driverParams.symdebugref)
                toDebug(t.sym);

            return t.ctype;
        }

        // Copy mutable version of backend type and add modifiers
        type* mctype = Type_toCtype(t.castMod(0));
        if (tybasic(mctype.Tty) == TYenum)
        {
            Classsym* s = mctype.Ttag;
            assert(s);
            type* tr = type_allocn(TYenum, mctype.Tnext);
            tr.Ttag = s; // enum tag name
            tr.Tcount++;
            tr.Tty |= modToTym(t.mod);
            return tr;
        }
        //printf("t = %p, Tflags = x%x\n", t, t.Tflags);
        return mctype;
    }

    static type* visitClass(TypeClass t)
    {
        if (t.mod == 0)
        {
            //printf("TypeClass::toCtype() %s\n", toChars());
            type* tc = type_struct_class(t.sym.toPrettyChars(true), t.sym.alignsize, t.sym.structsize, null, null, false, true, true, false);
            t.ctype = type_pointer(tc);
            /* Add in fields of the class
             * (after setting ctype to avoid infinite recursion)
             */
            if (driverParams.symdebug)
            {
                foreach (v; t.sym.fields)
                {
                    symbol_struct_addField(cast(Symbol*)tc.Ttag, v.ident.toChars(), Type_toCtype(v.type), v.offset);
                }
                if (auto bc = t.sym.baseClass)
                {
                    auto ptr_to_basetype = Type_toCtype(bc.type);
                    assert(ptr_to_basetype .Tty == TYnptr);
                    symbol_struct_addBaseClass(cast(Symbol*)tc.Ttag, ptr_to_basetype.Tnext, 0);
                }
            }

            if (driverParams.symdebugref)
                toDebug(t.sym);
            return t.ctype;
        }

        // Copy mutable version of backend type and add modifiers
        type* mctype = Type_toCtype(t.castMod(0));
        type* tr = type_allocn(tybasic(mctype.Tty), mctype.Tnext); // pointer to class instance
        tr.Tcount++;
        tr.Tty |= modToTym(t.mod);
        return tr;
    }

    type* tr;
    switch (t.ty)
    {
        default:        tr = visit        (t);                  break;
        case Tsarray:   tr = visitSArray  (t.isTypeSArray());   break;
        case Tarray:    tr = visitDArray  (t.isTypeDArray());   break;
        case Taarray:   tr = visitAArray  (t.isTypeAArray());   break;
        case Tpointer:  tr = visitPointer (t.isTypePointer());  break;
        case Tfunction: tr = visitFunction(t.isTypeFunction()); break;
        case Tdelegate: tr = visitDelegate(t.isTypeDelegate()); break;
        case Tstruct:   tr = visitStruct  (t.isTypeStruct());   break;
        case Tenum:     tr = visitEnum    (t.isTypeEnum());     break;
        case Tclass:    tr = visitClass   (t.isTypeClass());    break;
    }

    t.ctype = tr;
    return tr;
}
