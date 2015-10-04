// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.typinf;

import ddmd.declaration;
import ddmd.dmodule;
import ddmd.dscope;
import ddmd.dstruct;
import ddmd.dsymbol;
import ddmd.errors;
import ddmd.globals;
import ddmd.mtype;
import ddmd.visitor;

extern (C++) void toObjFile(Dsymbol ds, bool multiobj);

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
    assert(t.ty != Terror);
    genTypeInfo(t, sc);
    return t.vtinfo.type;
}

extern (C++) TypeInfoDeclaration getTypeInfoDeclaration(Type t)
{
    //printf("Type::getTypeInfoDeclaration() %s\n", t->toChars());
    switch (t.ty)
    {
    case Tpointer:
        return TypeInfoPointerDeclaration.create(t);
    case Tarray:
        return TypeInfoArrayDeclaration.create(t);
    case Tsarray:
        return TypeInfoStaticArrayDeclaration.create(t);
    case Taarray:
        return TypeInfoAssociativeArrayDeclaration.create(t);
    case Tstruct:
        return TypeInfoStructDeclaration.create(t);
    case Tvector:
        return TypeInfoVectorDeclaration.create(t);
    case Tenum:
        return TypeInfoEnumDeclaration.create(t);
    case Tfunction:
        return TypeInfoFunctionDeclaration.create(t);
    case Tdelegate:
        return TypeInfoDelegateDeclaration.create(t);
    case Ttuple:
        return TypeInfoTupleDeclaration.create(t);
    case Tclass:
        if ((cast(TypeClass)t).sym.isInterfaceDeclaration())
            return TypeInfoInterfaceDeclaration.create(t);
        else
            return TypeInfoClassDeclaration.create(t);
    default:
        return TypeInfoDeclaration.create(t, 0);
    }
}

extern (C++) bool isSpeculativeType(Type t)
{
    extern (C++) final class SpeculativeTypeVisitor : Visitor
    {
        alias visit = super.visit;
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

                    /* Bugzilla 14425: TypeInfo_Struct would refer the members of
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
extern (C++) static bool builtinTypeInfo(Type t)
{
    if (t.isTypeBasic() || t.ty == Tclass)
        return !t.mod;
    if (t.ty == Tarray)
    {
        Type next = t.nextOf();
        // strings are so common, make them builtin
        return !t.mod && (next.isTypeBasic() !is null && !next.mod || next.ty == Tchar && next.mod == MODimmutable || next.ty == Tchar && next.mod == MODconst);
    }
    return false;
}
