/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/typeinf.d, _typeinf.d)
 * Documentation:  https://dlang.org/phobos/dmd_typinf.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/typinf.d
 */

module dmd.typinf;

import dmd.declaration;
import dmd.dmodule;
import dmd.dscope;
import dmd.dclass;
import dmd.dstruct;
import dmd.errors;
import dmd.globals;
import dmd.gluelayer;
import dmd.mtype;
import dmd.visitor;

/****************************************************
 * Get the exact TypeInfo.
 */
extern (C++) void genTypeInfo(Type torig, Scope* sc)
{
    //printf("Type::genTypeInfo() %p, %s\n", this, toChars());
    if (!Type.dtypeinfo)
    {
        torig.error(Loc(), "TypeInfo not found. object.d may be incorrectly installed or corrupt, compile with -v switch");
        fatal();
    }

    Type t = torig.merge2(); // do this since not all Type's are merge'd
    if (!t.vtinfo)
    {
        if (t.isShared()) // does both 'shared' and 'shared const'
            t.vtinfo = TypeInfoSharedDeclaration.create(t);
        else if (t.isConst())
            t.vtinfo = TypeInfoConstDeclaration.create(t);
        else if (t.isImmutable())
            t.vtinfo = TypeInfoInvariantDeclaration.create(t);
        else if (t.isWild())
            t.vtinfo = TypeInfoWildDeclaration.create(t);
        else
            t.vtinfo = getTypeInfoDeclaration(t);
        assert(t.vtinfo);

        /* If this has a custom implementation in std/typeinfo, then
         * do not generate a COMDAT for it.
         */
        if (!builtinTypeInfo(t))
        {
            // Generate COMDAT
            if (sc) // if in semantic() pass
            {
                // Find module that will go all the way to an object file
                Module m = sc._module.importedFrom;
                m.members.push(t.vtinfo);
            }
            else // if in obj generation pass
            {
                toObjFile(t.vtinfo, global.params.multiobj);
            }
        }
    }
    if (!torig.vtinfo)
        torig.vtinfo = t.vtinfo; // Types aren't merged, but we can share the vtinfo's
    assert(torig.vtinfo);
}

extern (C++) Type getTypeInfoType(Type t, Scope* sc)
{
    assert(t.ty != Type.Kind.error);
    genTypeInfo(t, sc);
    return t.vtinfo.type;
}

extern (C++) TypeInfoDeclaration getTypeInfoDeclaration(Type t)
{
    //printf("Type::getTypeInfoDeclaration() %s\n", t.toChars());
    switch (t.ty)
    {
    case Type.Kind.pointer:
        return TypeInfoPointerDeclaration.create(t);
    case Type.Kind.array:
        return TypeInfoArrayDeclaration.create(t);
    case Type.Kind.staticArray:
        return TypeInfoStaticArrayDeclaration.create(t);
    case Type.Kind.associativeArray:
        return TypeInfoAssociativeArrayDeclaration.create(t);
    case Type.Kind.struct_:
        return TypeInfoStructDeclaration.create(t);
    case Type.Kind.vector:
        return TypeInfoVectorDeclaration.create(t);
    case Type.Kind.enum_:
        return TypeInfoEnumDeclaration.create(t);
    case Type.Kind.function_:
        return TypeInfoFunctionDeclaration.create(t);
    case Type.Kind.delegate_:
        return TypeInfoDelegateDeclaration.create(t);
    case Type.Kind.tuple:
        return TypeInfoTupleDeclaration.create(t);
    case Type.Kind.class_:
        if ((cast(TypeClass)t).sym.isInterfaceDeclaration())
            return TypeInfoInterfaceDeclaration.create(t);
        else
            return TypeInfoClassDeclaration.create(t);

    default:
        return TypeInfoDeclaration.create(t);
    }
}

extern (C++) bool isSpeculativeType(Type t)
{
    extern (C++) final class SpeculativeTypeVisitor : Visitor
    {
        alias visit = Visitor.visit;
    public:
        bool result;

        extern (D) this()
        {
        }

        override void visit(Type t)
        {
            Type tb = t.toBasetype();
            if (tb != t)
                tb.accept(this);
        }

        override void visit(TypeNext t)
        {
            if (t.next)
                t.next.accept(this);
        }

        override void visit(TypeBasic t)
        {
        }

        override void visit(TypeVector t)
        {
            t.basetype.accept(this);
        }

        override void visit(TypeAArray t)
        {
            t.index.accept(this);
            visit(cast(TypeNext)t);
        }

        override void visit(TypeFunction t)
        {
            visit(cast(TypeNext)t);
            // Currently TypeInfo_Function doesn't store parameter types.
        }

        override void visit(TypeStruct t)
        {
            StructDeclaration sd = t.sym;
            if (auto ti = sd.isInstantiated())
            {
                if (!ti.needsCodegen())
                {
                    if (ti.minst || sd.requestTypeInfo)
                        return;

                    /* https://issues.dlang.org/show_bug.cgi?id=14425
                     * TypeInfo_Struct would refer the members of
                     * struct (e.g. opEquals via xopEquals field), so if it's instantiated
                     * in speculative context, TypeInfo creation should also be
                     * stopped to avoid 'unresolved symbol' linker errors.
                     */
                    /* When -debug/-unittest is specified, all of non-root instances are
                     * automatically changed to speculative, and here is always reached
                     * from those instantiated non-root structs.
                     * Therefore, if the TypeInfo is not auctually requested,
                     * we have to elide its codegen.
                     */
                    result |= true;
                    return;
                }
            }
            else
            {
                //assert(!sd.inNonRoot() || sd.requestTypeInfo);    // valid?
            }
        }

        override void visit(TypeClass t)
        {
            ClassDeclaration sd = t.sym;
            if (auto ti = sd.isInstantiated())
            {
                if (!ti.needsCodegen() && !ti.minst)
                {
                    result |= true;
                }
            }
        }


        override void visit(TypeTuple t)
        {
            if (t.arguments)
            {
                for (size_t i = 0; i < t.arguments.dim; i++)
                {
                    Type tprm = (*t.arguments)[i].type;
                    if (tprm)
                        tprm.accept(this);
                    if (result)
                        return;
                }
            }
        }
    }

    scope SpeculativeTypeVisitor v = new SpeculativeTypeVisitor();
    t.accept(v);
    return v.result;
}

/* ========================================================================= */

/* These decide if there's an instance for them already in std.typeinfo,
 * because then the compiler doesn't need to build one.
 */
private bool builtinTypeInfo(Type t)
{
    if (t.isTypeBasic() || t.ty == Type.Kind.class_ || t.ty == Type.Kind.null_)
        return !t.mod;
    if (t.ty == Type.Kind.array)
    {
        Type next = t.nextOf();
        // strings are so common, make them builtin
        return !t.mod &&
               (next.isTypeBasic() !is null && !next.mod ||
                next.ty == Type.Kind.char_ && next.mod == MODFlags.immutable_ ||
                next.ty == Type.Kind.char_ && next.mod == MODFlags.const_);
    }
    return false;
}
