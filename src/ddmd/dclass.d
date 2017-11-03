/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/ddmd/dclass.d, _dclass.d)
 */

module ddmd.dclass;

// Online documentation: https://dlang.org/phobos/ddmd_dclass.html

import core.stdc.stdio;
import core.stdc.string;

import ddmd.aggregate;
import ddmd.arraytypes;
import ddmd.gluelayer;
import ddmd.declaration;
import ddmd.dscope;
import ddmd.dsymbol;
import ddmd.func;
import ddmd.globals;
import ddmd.id;
import ddmd.identifier;
import ddmd.mtype;
import ddmd.root.rmem;
import ddmd.semantic;
import ddmd.target;
import ddmd.visitor;

enum Abstract : int
{
    ABSfwdref = 0,      // whether an abstract class is not yet computed
    ABSyes,             // is abstract class
    ABSno,              // is not abstract class
}

alias ABSfwdref = Abstract.ABSfwdref;
alias ABSyes = Abstract.ABSyes;
alias ABSno = Abstract.ABSno;

/***********************************************************
 */
struct BaseClass
{
    Type type;          // (before semantic processing)

    ClassDeclaration sym;
    uint offset;        // 'this' pointer offset

    // for interfaces: Array of FuncDeclaration's making up the vtbl[]
    FuncDeclarations vtbl;

    // if BaseClass is an interface, these
    // are a copy of the InterfaceDeclaration.interfaces
    BaseClass[] baseInterfaces;

    extern (D) this(Type type)
    {
        //printf("BaseClass(this = %p, '%s')\n", this, type.toChars());
        this.type = type;
    }

    /****************************************
     * Fill in vtbl[] for base class based on member functions of class cd.
     * Input:
     *      vtbl            if !=NULL, fill it in
     *      newinstance     !=0 means all entries must be filled in by members
     *                      of cd, not members of any base classes of cd.
     * Returns:
     *      true if any entries were filled in by members of cd (not exclusively
     *      by base classes)
     */
    extern (C++) bool fillVtbl(ClassDeclaration cd, FuncDeclarations* vtbl, int newinstance)
    {
        bool result = false;

        //printf("BaseClass.fillVtbl(this='%s', cd='%s')\n", sym.toChars(), cd.toChars());
        if (vtbl)
            vtbl.setDim(sym.vtbl.dim);

        // first entry is ClassInfo reference
        for (size_t j = sym.vtblOffset(); j < sym.vtbl.dim; j++)
        {
            FuncDeclaration ifd = sym.vtbl[j].isFuncDeclaration();
            FuncDeclaration fd;
            TypeFunction tf;

            //printf("        vtbl[%d] is '%s'\n", j, ifd ? ifd.toChars() : "null");
            assert(ifd);

            // Find corresponding function in this class
            tf = ifd.type.toTypeFunction();
            fd = cd.findFunc(ifd.ident, tf);
            if (fd && !fd.isAbstract())
            {
                //printf("            found\n");
                // Check that calling conventions match
                if (fd.linkage != ifd.linkage)
                    fd.error("linkage doesn't match interface function");

                // Check that it is current
                //printf("newinstance = %d fd.toParent() = %s ifd.toParent() = %s\n",
                    //newinstance, fd.toParent().toChars(), ifd.toParent().toChars());
                if (newinstance && fd.toParent() != cd && ifd.toParent() == sym)
                    cd.error("interface function '%s' is not implemented", ifd.toFullSignature());

                if (fd.toParent() == cd)
                    result = true;
            }
            else
            {
                //printf("            not found %p\n", fd);
                // BUG: should mark this class as abstract?
                if (!cd.isAbstract())
                    cd.error("interface function '%s' is not implemented", ifd.toFullSignature());

                fd = null;
            }
            if (vtbl)
                (*vtbl)[j] = fd;
        }
        return result;
    }

    extern (C++) void copyBaseInterfaces(BaseClasses* vtblInterfaces)
    {
        //printf("+copyBaseInterfaces(), %s\n", sym.toChars());
        //    if (baseInterfaces.length)
        //      return;
        auto bc = cast(BaseClass*)mem.xcalloc(sym.interfaces.length, BaseClass.sizeof);
        baseInterfaces = bc[0 .. sym.interfaces.length];
        //printf("%s.copyBaseInterfaces()\n", sym.toChars());
        for (size_t i = 0; i < baseInterfaces.length; i++)
        {
            BaseClass* b = &baseInterfaces[i];
            BaseClass* b2 = sym.interfaces[i];

            assert(b2.vtbl.dim == 0); // should not be filled yet
            memcpy(b, b2, BaseClass.sizeof);

            if (i) // single inheritance is i==0
                vtblInterfaces.push(b); // only need for M.I.
            b.copyBaseInterfaces(vtblInterfaces);
        }
        //printf("-copyBaseInterfaces\n");
    }
}

struct ClassFlags
{
    alias Type = uint;

    enum Enum : int
    {
        isCOMclass = 0x1,
        noPointers = 0x2,
        hasOffTi = 0x4,
        hasCtor = 0x8,
        hasGetMembers = 0x10,
        hasTypeInfo = 0x20,
        isAbstract = 0x40,
        isCPPclass = 0x80,
        hasDtor = 0x100,
    }

    alias isCOMclass = Enum.isCOMclass;
    alias noPointers = Enum.noPointers;
    alias hasOffTi = Enum.hasOffTi;
    alias hasCtor = Enum.hasCtor;
    alias hasGetMembers = Enum.hasGetMembers;
    alias hasTypeInfo = Enum.hasTypeInfo;
    alias isAbstract = Enum.isAbstract;
    alias isCPPclass = Enum.isCPPclass;
    alias hasDtor = Enum.hasDtor;
}

/***********************************************************
 */
extern (C++) class ClassDeclaration : AggregateDeclaration
{
    extern (C++) __gshared
    {
        // Names found by reading object.d in druntime
        ClassDeclaration object;
        ClassDeclaration throwable;
        ClassDeclaration exception;
        ClassDeclaration errorException;
        ClassDeclaration cpp_type_info_ptr;   // Object.__cpp_type_info_ptr
    }

    ClassDeclaration baseClass; // NULL only if this is Object
    FuncDeclaration staticCtor;
    FuncDeclaration staticDtor;
    Dsymbols vtbl;              // Array of FuncDeclaration's making up the vtbl[]
    Dsymbols vtblFinal;         // More FuncDeclaration's that aren't in vtbl[]

    // Array of BaseClass's; first is super, rest are Interface's
    BaseClasses* baseclasses;

    /* Slice of baseclasses[] that does not include baseClass
     */
    BaseClass*[] interfaces;

    // array of base interfaces that have their own vtbl[]
    BaseClasses* vtblInterfaces;

    // the ClassInfo object for this ClassDeclaration
    TypeInfoClassDeclaration vclassinfo;

    bool com;           // true if this is a COM class (meaning it derives from IUnknown)
    bool cpp;           // true if this is a C++ interface
    bool isobjc;        // true if this is an Objective-C class/interface
    bool isscope;       // true if this is a scope class
    Abstract isabstract;
    int inuse;          // to prevent recursive attempts
    Baseok baseok;      // set the progress of base classes resolving

    Symbol* cpp_type_info_ptr_sym;      // cached instance of class Id.cpp_type_info_ptr

    final extern (D) this(Loc loc, Identifier id, BaseClasses* baseclasses, Dsymbols* members, bool inObject)
    {
        if (!id)
            id = Identifier.generateId("__anonclass");
        assert(id);

        super(loc, id);

        static __gshared const(char)* msg = "only object.d can define this reserved class name";

        if (baseclasses)
        {
            // Actually, this is a transfer
            this.baseclasses = baseclasses;
        }
        else
            this.baseclasses = new BaseClasses();

        this.members = members;

        //printf("ClassDeclaration(%s), dim = %d\n", id.toChars(), this.baseclasses.dim);

        // For forward references
        type = new TypeClass(this);

        if (id)
        {
            // Look for special class names
            if (id == Id.__sizeof || id == Id.__xalignof || id == Id._mangleof)
                error("illegal class name");

            // BUG: What if this is the wrong TypeInfo, i.e. it is nested?
            if (id.toChars()[0] == 'T')
            {
                if (id == Id.TypeInfo)
                {
                    if (!inObject)
                        error("%s", msg);
                    Type.dtypeinfo = this;
                }
                if (id == Id.TypeInfo_Class)
                {
                    if (!inObject)
                        error("%s", msg);
                    Type.typeinfoclass = this;
                }
                if (id == Id.TypeInfo_Interface)
                {
                    if (!inObject)
                        error("%s", msg);
                    Type.typeinfointerface = this;
                }
                if (id == Id.TypeInfo_Struct)
                {
                    if (!inObject)
                        error("%s", msg);
                    Type.typeinfostruct = this;
                }
                if (id == Id.TypeInfo_Pointer)
                {
                    if (!inObject)
                        error("%s", msg);
                    Type.typeinfopointer = this;
                }
                if (id == Id.TypeInfo_Array)
                {
                    if (!inObject)
                        error("%s", msg);
                    Type.typeinfoarray = this;
                }
                if (id == Id.TypeInfo_StaticArray)
                {
                    //if (!inObject)
                    //    Type.typeinfostaticarray.error("%s", msg);
                    Type.typeinfostaticarray = this;
                }
                if (id == Id.TypeInfo_AssociativeArray)
                {
                    if (!inObject)
                        error("%s", msg);
                    Type.typeinfoassociativearray = this;
                }
                if (id == Id.TypeInfo_Enum)
                {
                    if (!inObject)
                        error("%s", msg);
                    Type.typeinfoenum = this;
                }
                if (id == Id.TypeInfo_Function)
                {
                    if (!inObject)
                        error("%s", msg);
                    Type.typeinfofunction = this;
                }
                if (id == Id.TypeInfo_Delegate)
                {
                    if (!inObject)
                        error("%s", msg);
                    Type.typeinfodelegate = this;
                }
                if (id == Id.TypeInfo_Tuple)
                {
                    if (!inObject)
                        error("%s", msg);
                    Type.typeinfotypelist = this;
                }
                if (id == Id.TypeInfo_Const)
                {
                    if (!inObject)
                        error("%s", msg);
                    Type.typeinfoconst = this;
                }
                if (id == Id.TypeInfo_Invariant)
                {
                    if (!inObject)
                        error("%s", msg);
                    Type.typeinfoinvariant = this;
                }
                if (id == Id.TypeInfo_Shared)
                {
                    if (!inObject)
                        error("%s", msg);
                    Type.typeinfoshared = this;
                }
                if (id == Id.TypeInfo_Wild)
                {
                    if (!inObject)
                        error("%s", msg);
                    Type.typeinfowild = this;
                }
                if (id == Id.TypeInfo_Vector)
                {
                    if (!inObject)
                        error("%s", msg);
                    Type.typeinfovector = this;
                }
            }

            if (id == Id.Object)
            {
                if (!inObject)
                    error("%s", msg);
                object = this;
            }

            if (id == Id.Throwable)
            {
                if (!inObject)
                    error("%s", msg);
                throwable = this;
            }
            if (id == Id.Exception)
            {
                if (!inObject)
                    error("%s", msg);
                exception = this;
            }
            if (id == Id.Error)
            {
                if (!inObject)
                    error("%s", msg);
                errorException = this;
            }
            if (id == Id.cpp_type_info_ptr)
            {
                if (!inObject)
                    error("%s", msg);
                cpp_type_info_ptr = this;
            }
        }
        baseok = BASEOKnone;
    }

    static ClassDeclaration create(Loc loc, Identifier id, BaseClasses* baseclasses, Dsymbols* members, bool inObject)
    {
        return new ClassDeclaration(loc, id, baseclasses, members, inObject);
    }

    override Dsymbol syntaxCopy(Dsymbol s)
    {
        //printf("ClassDeclaration.syntaxCopy('%s')\n", toChars());
        ClassDeclaration cd =
            s ? cast(ClassDeclaration)s
              : new ClassDeclaration(loc, ident, null, null, false);

        cd.storage_class |= storage_class;

        cd.baseclasses.setDim(this.baseclasses.dim);
        for (size_t i = 0; i < cd.baseclasses.dim; i++)
        {
            BaseClass* b = (*this.baseclasses)[i];
            auto b2 = new BaseClass(b.type.syntaxCopy());
            (*cd.baseclasses)[i] = b2;
        }

        return ScopeDsymbol.syntaxCopy(cd);
    }

    override Scope* newScope(Scope* sc)
    {
        auto sc2 = super.newScope(sc);
        if (isCOMclass())
        {
            /* This enables us to use COM objects under Linux and
             * work with things like XPCOM
             */
            sc2.linkage = Target.systemLinkage();
        }
        return sc2;
    }

    /*********************************************
     * Determine if 'this' is a base class of cd.
     * This is used to detect circular inheritance only.
     */
    final bool isBaseOf2(ClassDeclaration cd)
    {
        if (!cd)
            return false;
        //printf("ClassDeclaration.isBaseOf2(this = '%s', cd = '%s')\n", toChars(), cd.toChars());
        for (size_t i = 0; i < cd.baseclasses.dim; i++)
        {
            BaseClass* b = (*cd.baseclasses)[i];
            if (b.sym == this || isBaseOf2(b.sym))
                return true;
        }
        return false;
    }

    enum OFFSET_RUNTIME = 0x76543210;
    enum OFFSET_FWDREF = 0x76543211;

    /*******************************************
     * Determine if 'this' is a base class of cd.
     */
    bool isBaseOf(ClassDeclaration cd, int* poffset)
    {
        //printf("ClassDeclaration.isBaseOf(this = '%s', cd = '%s')\n", toChars(), cd.toChars());
        if (poffset)
            *poffset = 0;
        while (cd)
        {
            /* cd.baseClass might not be set if cd is forward referenced.
             */
            if (!cd.baseClass && cd.semanticRun < PASSsemanticdone && !cd.isInterfaceDeclaration())
            {
                cd.semantic(null);
                if (!cd.baseClass && cd.semanticRun < PASSsemanticdone)
                    cd.error("base class is forward referenced by %s", toChars());
            }

            if (this == cd.baseClass)
                return true;

            cd = cd.baseClass;
        }
        return false;
    }

    /*********************************************
     * Determine if 'this' has complete base class information.
     * This is used to detect forward references in covariant overloads.
     */
    final bool isBaseInfoComplete() const
    {
        return baseok >= BASEOKdone;
    }

    override final Dsymbol search(Loc loc, Identifier ident, int flags = SearchLocalsOnly)
    {
        //printf("%s.ClassDeclaration.search('%s', flags=x%x)\n", toChars(), ident.toChars(), flags);
        //if (_scope) printf("%s baseok = %d\n", toChars(), baseok);
        if (_scope && baseok < BASEOKdone)
        {
            if (!inuse)
            {
                // must semantic on base class/interfaces
                ++inuse;
                semantic(this, null);
                --inuse;
            }
        }

        if (!members || !symtab) // opaque or addMember is not yet done
        {
            error("is forward referenced when looking for '%s'", ident.toChars());
            //*(char*)0=0;
            return null;
        }

        auto s = ScopeDsymbol.search(loc, ident, flags);

        // don't search imports of base classes
        if (flags & SearchImportsOnly)
            return s;

        if (!s)
        {
            // Search bases classes in depth-first, left to right order
            for (size_t i = 0; i < baseclasses.dim; i++)
            {
                BaseClass* b = (*baseclasses)[i];
                if (b.sym)
                {
                    if (!b.sym.symtab)
                        error("base %s is forward referenced", b.sym.ident.toChars());
                    else
                    {
                        import ddmd.access : symbolIsVisible;

                        s = b.sym.search(loc, ident, flags);
                        if (!s)
                            continue;
                        else if (s == this) // happens if s is nested in this and derives from this
                            s = null;
                        else if (!(flags & IgnoreSymbolVisibility) && !(s.prot().kind == PROTprotected) && !symbolIsVisible(this, s))
                            s = null;
                        else
                            break;
                    }
                }
            }
        }
        return s;
    }

    /************************************
     * Search base classes in depth-first, left-to-right order for
     * a class or interface named 'ident'.
     * Stops at first found. Does not look for additional matches.
     * Params:
     *  ident = identifier to search for
     * Returns:
     *  ClassDeclaration if found, null if not
     */
    final ClassDeclaration searchBase(Identifier ident)
    {
        foreach (b; *baseclasses)
        {
            auto cdb = b.type.isClassHandle();
            if (!cdb) // https://issues.dlang.org/show_bug.cgi?id=10616
                return null;
            if (cdb.ident.equals(ident))
                return cdb;
            auto result = cdb.searchBase(ident);
            if (result)
                return result;
        }
        return null;
    }

    final override void finalizeSize()
    {
        assert(sizeok != SIZEOKdone);

        // Set the offsets of the fields and determine the size of the class
        if (baseClass)
        {
            assert(baseClass.sizeok == SIZEOKdone);

            alignsize = baseClass.alignsize;
            structsize = baseClass.structsize;
            if (cpp && global.params.isWindows)
                structsize = (structsize + alignsize - 1) & ~(alignsize - 1);
        }
        else if (isInterfaceDeclaration())
        {
            if (interfaces.length == 0)
            {
                alignsize = Target.ptrsize;
                structsize = Target.ptrsize;      // allow room for __vptr
            }
        }
        else
        {
            alignsize = Target.ptrsize;
            structsize = Target.ptrsize;      // allow room for __vptr
            if (!cpp)
                structsize += Target.ptrsize; // allow room for __monitor
        }

        //printf("finalizeSize() %s, sizeok = %d\n", toChars(), sizeok);
        size_t bi = 0;                  // index into vtblInterfaces[]

        /****
         * Runs through the inheritance graph to set the BaseClass.offset fields.
         * Recursive in order to account for the size of the interface classes, if they are
         * more than just interfaces.
         * Params:
         *      cd = interface to look at
         *      baseOffset = offset of where cd will be placed
         * Returns:
         *      subset of instantiated size used by cd for interfaces
         */
        uint membersPlace(ClassDeclaration cd, uint baseOffset)
        {
            //printf("    membersPlace(%s, %d)\n", cd.toChars(), baseOffset);
            uint offset = baseOffset;

            foreach (BaseClass* b; cd.interfaces)
            {
                if (b.sym.sizeok != SIZEOKdone)
                    b.sym.finalizeSize();
                assert(b.sym.sizeok == SIZEOKdone);

                if (!b.sym.alignsize)
                    b.sym.alignsize = Target.ptrsize;
                alignmember(b.sym.alignsize, b.sym.alignsize, &offset);
                assert(bi < vtblInterfaces.dim);

                BaseClass* bv = (*vtblInterfaces)[bi];
                if (b.sym.interfaces.length == 0)
                {
                    //printf("\tvtblInterfaces[%d] b=%p b.sym = %s, offset = %d\n", bi, bv, bv.sym.toChars(), offset);
                    bv.offset = offset;
                    ++bi;
                    // All the base interfaces down the left side share the same offset
                    for (BaseClass* b2 = bv; b2.baseInterfaces.length; )
                    {
                        b2 = &b2.baseInterfaces[0];
                        b2.offset = offset;
                        //printf("\tvtblInterfaces[%d] b=%p   sym = %s, offset = %d\n", bi, b2, b2.sym.toChars(), b2.offset);
                    }
                }
                membersPlace(b.sym, offset);
                //printf(" %s size = %d\n", b.sym.toChars(), b.sym.structsize);
                offset += b.sym.structsize;
                if (alignsize < b.sym.alignsize)
                    alignsize = b.sym.alignsize;
            }
            return offset - baseOffset;
        }

        structsize += membersPlace(this, structsize);

        if (isInterfaceDeclaration())
        {
            sizeok = SIZEOKdone;
            return;
        }

        // FIXME: Currently setFieldOffset functions need to increase fields
        // to calculate each variable offsets. It can be improved later.
        fields.setDim(0);

        uint offset = structsize;
        foreach (s; *members)
        {
            s.setFieldOffset(this, &offset, false);
        }

        sizeok = SIZEOKdone;

        // Calculate fields[i].overlapped
        checkOverlappedFields();
    }

    final bool isFuncHidden(FuncDeclaration fd)
    {
        //printf("ClassDeclaration.isFuncHidden(class = %s, fd = %s)\n", toChars(), fd.toPrettyChars());
        Dsymbol s = search(Loc(), fd.ident, IgnoreAmbiguous | IgnoreErrors);
        if (!s)
        {
            //printf("not found\n");
            /* Because, due to a hack, if there are multiple definitions
             * of fd.ident, NULL is returned.
             */
            return false;
        }
        s = s.toAlias();
        if (auto os = s.isOverloadSet())
        {
            foreach (sm; os.a)
            {
                auto fm = sm.isFuncDeclaration();
                if (overloadApply(fm, s => fd == s.isFuncDeclaration()))
                    return false;
            }
            return true;
        }
        else
        {
            auto f = s.isFuncDeclaration();
            //printf("%s fdstart = %p\n", s.kind(), fdstart);
            if (overloadApply(f, s => fd == s.isFuncDeclaration()))
                return false;
            return !fd.parent.isTemplateMixin();
        }
    }

    /****************
     * Find virtual function matching identifier and type.
     * Used to build virtual function tables for interface implementations.
     * Params:
     *  ident = function's identifier
     *  tf = function's type
     * Returns:
     *  function symbol if found, null if not
     * Errors:
     *  prints error message if more than one match
     */
    final FuncDeclaration findFunc(Identifier ident, TypeFunction tf)
    {
        //printf("ClassDeclaration.findFunc(%s, %s) %s\n", ident.toChars(), tf.toChars(), toChars());
        FuncDeclaration fdmatch = null;
        FuncDeclaration fdambig = null;

        void searchVtbl(ref Dsymbols vtbl)
        {
            foreach (s; vtbl)
            {
                auto fd = s.isFuncDeclaration();
                if (!fd)
                    continue;

                // the first entry might be a ClassInfo
                //printf("\t[%d] = %s\n", i, fd.toChars());
                if (ident == fd.ident && fd.type.covariant(tf) == 1)
                {
                    //printf("fd.parent.isClassDeclaration() = %p\n", fd.parent.isClassDeclaration());
                    if (!fdmatch)
                        goto Lfd;
                    if (fd == fdmatch)
                        goto Lfdmatch;

                    {
                    // Function type matching: exact > covariant
                    MATCH m1 = tf.equals(fd.type) ? MATCH.exact : MATCH.nomatch;
                    MATCH m2 = tf.equals(fdmatch.type) ? MATCH.exact : MATCH.nomatch;
                    if (m1 > m2)
                        goto Lfd;
                    else if (m1 < m2)
                        goto Lfdmatch;
                    }
                    {
                    MATCH m1 = (tf.mod == fd.type.mod) ? MATCH.exact : MATCH.nomatch;
                    MATCH m2 = (tf.mod == fdmatch.type.mod) ? MATCH.exact : MATCH.nomatch;
                    if (m1 > m2)
                        goto Lfd;
                    else if (m1 < m2)
                        goto Lfdmatch;
                    }
                    {
                    // The way of definition: non-mixin > mixin
                    MATCH m1 = fd.parent.isClassDeclaration() ? MATCH.exact : MATCH.nomatch;
                    MATCH m2 = fdmatch.parent.isClassDeclaration() ? MATCH.exact : MATCH.nomatch;
                    if (m1 > m2)
                        goto Lfd;
                    else if (m1 < m2)
                        goto Lfdmatch;
                    }

                    fdambig = fd;
                    //printf("Lambig fdambig = %s %s [%s]\n", fdambig.toChars(), fdambig.type.toChars(), fdambig.loc.toChars());
                    continue;

                Lfd:
                    fdmatch = fd;
                    fdambig = null;
                    //printf("Lfd fdmatch = %s %s [%s]\n", fdmatch.toChars(), fdmatch.type.toChars(), fdmatch.loc.toChars());
                    continue;

                Lfdmatch:
                    continue;
                }
                //else printf("\t\t%d\n", fd.type.covariant(tf));
            }
        }

        searchVtbl(vtbl);
        for (auto cd = this; cd; cd = cd.baseClass)
        {
            searchVtbl(cd.vtblFinal);
        }

        if (fdambig)
            error("ambiguous virtual function %s", fdambig.toChars());

        return fdmatch;
    }

    /****************************************
     */
    final bool isCOMclass() const
    {
        return com;
    }

    bool isCOMinterface() const
    {
        return false;
    }

    final bool isCPPclass() const
    {
        return cpp;
    }

    bool isCPPinterface() const
    {
        return false;
    }

    /****************************************
     */
    final bool isAbstract()
    {
        enum log = false;
        if (isabstract != ABSfwdref)
            return isabstract == ABSyes;

        if (log) printf("isAbstract(%s)\n", toChars());

        bool no()  { if (log) printf("no\n");  isabstract = ABSno;  return false; }
        bool yes() { if (log) printf("yes\n"); isabstract = ABSyes; return true;  }

        if (storage_class & STCabstract || _scope && _scope.stc & STCabstract)
            return yes();

        if (errors)
            return no();

        /* https://issues.dlang.org/show_bug.cgi?id=11169
         * Resolve forward references to all class member functions,
         * and determine whether this class is abstract.
         */
        extern (C++) static int func(Dsymbol s, void* param)
        {
            auto fd = s.isFuncDeclaration();
            if (!fd)
                return 0;
            if (fd.storage_class & STCstatic)
                return 0;

            if (fd.isAbstract())
                return 1;
            return 0;
        }

        for (size_t i = 0; i < members.dim; i++)
        {
            auto s = (*members)[i];
            if (s.apply(&func, cast(void*)this))
            {
                return yes();
            }
        }

        /* If the base class is not abstract, then this class cannot
         * be abstract.
         */
        if (!isInterfaceDeclaration() && (!baseClass || !baseClass.isAbstract()))
            return no();

        /* If any abstract functions are inherited, but not overridden,
         * then the class is abstract. Do this by checking the vtbl[].
         * Need to do semantic() on class to fill the vtbl[].
         */
        this.semantic(null);

        /* The next line should work, but does not because when ClassDeclaration.semantic()
         * is called recursively it can set PASSsemanticdone without finishing it.
         */
        //if (semanticRun < PASSsemanticdone)
        {
            /* Could not complete semantic(). Try running semantic() on
             * each of the virtual functions,
             * which will fill in the vtbl[] overrides.
             */
            extern (C++) static int virtualSemantic(Dsymbol s, void* param)
            {
                auto fd = s.isFuncDeclaration();
                if (fd && !(fd.storage_class & STCstatic) && !fd.isUnitTestDeclaration())
                    fd.semantic(null);
                return 0;
            }

            for (size_t i = 0; i < members.dim; i++)
            {
                auto s = (*members)[i];
                s.apply(&virtualSemantic, cast(void*)this);
            }
        }

        /* Finally, check the vtbl[]
         */
        foreach (i; 1 .. vtbl.dim)
        {
            auto fd = vtbl[i].isFuncDeclaration();
            //if (fd) printf("\tvtbl[%d] = [%s] %s\n", i, fd.loc.toChars(), fd.toPrettyChars());
            if (!fd || fd.isAbstract())
            {
                return yes();
            }
        }

        return no();
    }

    /****************************************
     * Determine if slot 0 of the vtbl[] is reserved for something else.
     * For class objects, yes, this is where the classinfo ptr goes.
     * For COM interfaces, no.
     * For non-COM interfaces, yes, this is where the Interface ptr goes.
     * Returns:
     *      0       vtbl[0] is first virtual function pointer
     *      1       vtbl[0] is classinfo/interfaceinfo pointer
     */
    int vtblOffset() const
    {
        return cpp ? 0 : 1;
    }

    /****************************************
     */
    override const(char)* kind() const
    {
        return "class";
    }

    /****************************************
     */
    override final void addLocalClass(ClassDeclarations* aclasses)
    {
        aclasses.push(this);
    }

    // Back end
    Symbol* vtblsym;

    override final inout(ClassDeclaration) isClassDeclaration() inout
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class InterfaceDeclaration : ClassDeclaration
{
    extern (D) this(Loc loc, Identifier id, BaseClasses* baseclasses)
    {
        super(loc, id, baseclasses, null, false);
        if (id == Id.IUnknown) // IUnknown is the root of all COM interfaces
        {
            com = true;
            cpp = true; // IUnknown is also a C++ interface
        }
    }

    override Dsymbol syntaxCopy(Dsymbol s)
    {
        InterfaceDeclaration id =
            s ? cast(InterfaceDeclaration)s
              : new InterfaceDeclaration(loc, ident, null);
        return ClassDeclaration.syntaxCopy(id);
    }


    override Scope* newScope(Scope* sc)
    {
        auto sc2 = super.newScope(sc);
        if (com)
            sc2.linkage = LINKwindows;
        else if (cpp)
            sc2.linkage = LINKcpp;
        else if (isobjc)
            sc2.linkage = LINKobjc;
        return sc2;
    }

    /*******************************************
     * Determine if 'this' is a base class of cd.
     * (Actually, if it is an interface supported by cd)
     * Output:
     *      *poffset        offset to start of class
     *                      OFFSET_RUNTIME  must determine offset at runtime
     * Returns:
     *      false   not a base
     *      true    is a base
     */
    override bool isBaseOf(ClassDeclaration cd, int* poffset)
    {
        //printf("%s.InterfaceDeclaration.isBaseOf(cd = '%s')\n", toChars(), cd.toChars());
        assert(!baseClass);
        foreach (j, b; cd.interfaces)
        {
            //printf("\tX base %s\n", b.sym.toChars());
            if (this == b.sym)
            {
                //printf("\tfound at offset %d\n", b.offset);
                if (poffset)
                {
                    // don't return incorrect offsets
                    // https://issues.dlang.org/show_bug.cgi?id=16980
                    *poffset = cd.sizeok == SIZEOKdone ? b.offset : OFFSET_FWDREF;
                }
                // printf("\tfound at offset %d\n", b.offset);
                return true;
            }
            if (isBaseOf(b, poffset))
                return true;
        }
        if (cd.baseClass && isBaseOf(cd.baseClass, poffset))
            return true;

        if (poffset)
            *poffset = 0;
        return false;
    }

    bool isBaseOf(BaseClass* bc, int* poffset)
    {
        //printf("%s.InterfaceDeclaration.isBaseOf(bc = '%s')\n", toChars(), bc.sym.toChars());
        for (size_t j = 0; j < bc.baseInterfaces.length; j++)
        {
            BaseClass* b = &bc.baseInterfaces[j];
            //printf("\tY base %s\n", b.sym.toChars());
            if (this == b.sym)
            {
                //printf("\tfound at offset %d\n", b.offset);
                if (poffset)
                {
                    *poffset = b.offset;
                }
                return true;
            }
            if (isBaseOf(b, poffset))
            {
                return true;
            }
        }

        if (poffset)
            *poffset = 0;
        return false;
    }

    /*******************************************
     */
    override const(char)* kind() const
    {
        return "interface";
    }

    /****************************************
     * Determine if slot 0 of the vtbl[] is reserved for something else.
     * For class objects, yes, this is where the ClassInfo ptr goes.
     * For COM interfaces, no.
     * For non-COM interfaces, yes, this is where the Interface ptr goes.
     */
    override int vtblOffset() const
    {
        if (isCOMinterface() || isCPPinterface())
            return 0;
        return 1;
    }

    override bool isCPPinterface() const
    {
        return cpp;
    }

    override bool isCOMinterface() const
    {
        return com;
    }

    override inout(InterfaceDeclaration) isInterfaceDeclaration() inout
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}
