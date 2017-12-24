/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/ddmd/dsymbolsem.d, _dsymbolsem.d)
 */

module ddmd.dsymbolsem;

// Online documentation: https://dlang.org/phobos/ddmd_dsymbolsem.html

import core.stdc.stdio;
import core.stdc.string;

import ddmd.aggregate;
import ddmd.aliasthis;
import ddmd.arraytypes;
import ddmd.astcodegen;
import ddmd.attrib;
import ddmd.blockexit;
import ddmd.clone;
import ddmd.dcast;
import ddmd.dclass;
import ddmd.declaration;
import ddmd.denum;
import ddmd.dimport;
import ddmd.dinterpret;
import ddmd.dmodule;
import ddmd.dscope;
import ddmd.dstruct;
import ddmd.dsymbol;
import ddmd.dtemplate;
import ddmd.dversion;
import ddmd.errors;
import ddmd.escape;
import ddmd.expression;
import ddmd.expressionsem;
import ddmd.func;
import ddmd.globals;
import ddmd.gluelayer;
import ddmd.id;
import ddmd.identifier;
import ddmd.init;
import ddmd.initsem;
import ddmd.hdrgen;
import ddmd.mars;
import ddmd.mtype;
import ddmd.nogc;
import ddmd.nspace;
import ddmd.objc;
import ddmd.opover;
import ddmd.parse;
import ddmd.root.filename;
import ddmd.root.outbuffer;
import ddmd.root.rmem;
import ddmd.root.rootobject;
import ddmd.sideeffect;
import ddmd.statementsem;
import ddmd.staticassert;
import ddmd.tokens;
import ddmd.utf;
import ddmd.utils;
import ddmd.semantic;
import ddmd.statement;
import ddmd.target;
import ddmd.templateparamsem;
import ddmd.typesem;
import ddmd.visitor;

version(IN_LLVM)
{
    import gen.dpragma;
    import gen.llvmhelpers;
}

enum LOG = false;

/*************************************
 * Does semantic analysis on the public face of declarations.
 */
extern(C++) void dsymbolSemantic(Dsymbol dsym, Scope* sc)
{
    scope v = new DsymbolSemanticVisitor(sc);
    dsym.accept(v);
}

extern(C++) final class Semantic2Visitor : Visitor
{
    alias visit = super.visit;
    Scope* sc;
    this(Scope* sc)
    {
        this.sc = sc;
    }

    override void visit(Dsymbol) {}

    override void visit(StaticAssert sa)
    {
        //printf("StaticAssert::semantic2() %s\n", toChars());
        auto sds = new ScopeDsymbol();
        sc = sc.push(sds);
        sc.tinst = null;
        sc.minst = null;

        import ddmd.staticcond;
        bool errors;
        bool result = evalStaticCondition(sc, sa.exp, sa.exp, errors);
        sc = sc.pop();
        if (errors)
        {
            errorSupplemental(sa.loc, "while evaluating: `static assert(%s)`", sa.exp.toChars());
        }
        else if (!result)
        {
            if (sa.msg)
            {
                sc = sc.startCTFE();
                sa.msg = sa.msg.expressionSemantic(sc);
                sa.msg = resolveProperties(sc, sa.msg);
                sc = sc.endCTFE();
                sa.msg = sa.msg.ctfeInterpret();
                if (StringExp se = sa.msg.toStringExp())
                {
                    // same with pragma(msg)
                    se = se.toUTF8(sc);
                    sa.error("\"%.*s\"", cast(int)se.len, se.string);
                }
                else
                    sa.error("%s", sa.msg.toChars());
            }
            else
                sa.error("`%s` is false", sa.exp.toChars());
            if (sc.tinst)
                sc.tinst.printInstantiationTrace();
            if (!global.gag)
                fatal();
        }
    }

    override void visit(TemplateInstance tempinst)
    {
        if (tempinst.semanticRun >= PASSsemantic2)
            return;
        tempinst.semanticRun = PASSsemantic2;
        static if (LOG)
        {
            printf("+TemplateInstance.semantic2('%s')\n", tempinst.toChars());
        }
        if (!tempinst.errors && tempinst.members)
        {
            TemplateDeclaration tempdecl = tempinst.tempdecl.isTemplateDeclaration();
            assert(tempdecl);

            sc = tempdecl._scope;
            assert(sc);
            sc = sc.push(tempinst.argsym);
            sc = sc.push(tempinst);
            sc.tinst = tempinst;
            sc.minst = tempinst.minst;

            int needGagging = (tempinst.gagged && !global.gag);
            uint olderrors = global.errors;
            int oldGaggedErrors = -1; // dead-store to prevent spurious warning
            if (needGagging)
                oldGaggedErrors = global.startGagging();

            for (size_t i = 0; i < tempinst.members.dim; i++)
            {
                Dsymbol s = (*tempinst.members)[i];
                static if (LOG)
                {
                    printf("\tmember '%s', kind = '%s'\n", s.toChars(), s.kind());
                }
                s.semantic2(sc);
                if (tempinst.gagged && global.errors != olderrors)
                    break;
            }

            if (global.errors != olderrors)
            {
                if (!tempinst.errors)
                {
                    if (!tempdecl.literal)
                        tempinst.error(tempinst.loc, "error instantiating");
                    if (tempinst.tinst)
                        tempinst.tinst.printInstantiationTrace();
                }
                tempinst.errors = true;
            }
            if (needGagging)
                global.endGagging(oldGaggedErrors);

            sc = sc.pop();
            sc.pop();
        }
        static if (LOG)
        {
            printf("-TemplateInstance.semantic2('%s')\n", tempinst.toChars());
        }
    }

    override void visit(TemplateMixin tmix)
    {
        if (tmix.semanticRun >= PASSsemantic2)
            return;
        tmix.semanticRun = PASSsemantic2;
        static if (LOG)
        {
            printf("+TemplateMixin.semantic2('%s')\n", tmix.toChars());
        }
        if (tmix.members)
        {
            assert(sc);
            sc = sc.push(tmix.argsym);
            sc = sc.push(tmix);
            for (size_t i = 0; i < tmix.members.dim; i++)
            {
                Dsymbol s = (*tmix.members)[i];
                static if (LOG)
                {
                    printf("\tmember '%s', kind = '%s'\n", s.toChars(), s.kind());
                }
                s.semantic2(sc);
            }
            sc = sc.pop();
            sc.pop();
        }
        static if (LOG)
        {
            printf("-TemplateMixin.semantic2('%s')\n", tmix.toChars());
        }
    }

    override void visit(VarDeclaration vd)
    {
        if (vd.semanticRun < PASSsemanticdone && vd.inuse)
            return;

        //printf("VarDeclaration::semantic2('%s')\n", toChars());

        if (vd._init && !vd.toParent().isFuncDeclaration())
        {
            vd.inuse++;
            version (none)
            {
                ExpInitializer ei = vd._init.isExpInitializer();
                if (ei)
                {
                    ei.exp.print();
                    printf("type = %p\n", ei.exp.type);
                }
            }
            // https://issues.dlang.org/show_bug.cgi?id=14166
            // Don't run CTFE for the temporary variables inside typeof
            vd._init = vd._init.semantic(sc, vd.type, sc.intypeof == 1 ? INITnointerpret : INITinterpret);
            vd.inuse--;
        }
        if (vd._init && vd.storage_class & STCmanifest)
        {
            /* Cannot initializer enums with CTFE classreferences and addresses of struct literals.
             * Scan initializer looking for them. Issue error if found.
             */
            if (ExpInitializer ei = vd._init.isExpInitializer())
            {
                static bool hasInvalidEnumInitializer(Expression e)
                {
                    static bool arrayHasInvalidEnumInitializer(Expressions* elems)
                    {
                        foreach (e; *elems)
                        {
                            if (e && hasInvalidEnumInitializer(e))
                                return true;
                        }
                        return false;
                    }

                    if (e.op == TOKclassreference)
                        return true;
                    if (e.op == TOKaddress && (cast(AddrExp)e).e1.op == TOKstructliteral)
                        return true;
                    if (e.op == TOKarrayliteral)
                        return arrayHasInvalidEnumInitializer((cast(ArrayLiteralExp)e).elements);
                    if (e.op == TOKstructliteral)
                        return arrayHasInvalidEnumInitializer((cast(StructLiteralExp)e).elements);
                    if (e.op == TOKassocarrayliteral)
                    {
                        AssocArrayLiteralExp ae = cast(AssocArrayLiteralExp)e;
                        return arrayHasInvalidEnumInitializer(ae.values) ||
                               arrayHasInvalidEnumInitializer(ae.keys);
                    }
                    return false;
                }

                if (hasInvalidEnumInitializer(ei.exp))
                    vd.error(": Unable to initialize enum with class or pointer to struct. Use static const variable instead.");
            }
        }
        else if (vd._init && vd.isThreadlocal())
        {
            if ((vd.type.ty == Tclass) && vd.type.isMutable() && !vd.type.isShared())
            {
                ExpInitializer ei = vd._init.isExpInitializer();
                if (ei && ei.exp.op == TOKclassreference)
                    vd.error("is mutable. Only const or immutable class thread local variable are allowed, not %s", vd.type.toChars());
            }
            else if (vd.type.ty == Tpointer && vd.type.nextOf().ty == Tstruct && vd.type.nextOf().isMutable() && !vd.type.nextOf().isShared())
            {
                ExpInitializer ei = vd._init.isExpInitializer();
                if (ei && ei.exp.op == TOKaddress && (cast(AddrExp)ei.exp).e1.op == TOKstructliteral)
                {
                    vd.error("is a pointer to mutable struct. Only pointers to const, immutable or shared struct thread local variable are allowed, not %s", vd.type.toChars());
                }
            }
        }
        vd.semanticRun = PASSsemantic2done;
    }

    override void visit(Module mod)
    {
        //printf("Module::semantic2('%s'): parent = %p\n", toChars(), parent);
        if (mod.semanticRun != PASSsemanticdone) // semantic() not completed yet - could be recursive call
            return;
        mod.semanticRun = PASSsemantic2;
        // Note that modules get their own scope, from scratch.
        // This is so regardless of where in the syntax a module
        // gets imported, it is unaffected by context.
        Scope* sc = Scope.createGlobal(mod); // create root scope
        //printf("Module = %p\n", sc.scopesym);
        // Pass 2 semantic routines: do initializers and function bodies
        for (size_t i = 0; i < mod.members.dim; i++)
        {
            Dsymbol s = (*mod.members)[i];
            s.semantic2(sc);
        }
        if (mod.userAttribDecl)
        {
            mod.userAttribDecl.semantic2(sc);
        }
        sc = sc.pop();
        sc.pop();
        mod.semanticRun = PASSsemantic2done;
        //printf("-Module::semantic2('%s'): parent = %p\n", toChars(), parent);
    }

    override void visit(FuncDeclaration fd)
    {
        if (fd.semanticRun >= PASSsemantic2done)
            return;
        assert(fd.semanticRun <= PASSsemantic2);

        fd.semanticRun = PASSsemantic2;

        objc.setSelector(fd, sc);
        objc.validateSelector(fd);
        if (ClassDeclaration cd = fd.parent.isClassDeclaration())
        {
            objc.checkLinkage(fd);
        }
    }

    override void visit(Import i)
    {
        //printf("Import::semantic2('%s')\n", toChars());
        if (i.mod)
        {
            i.mod.semantic2(null);
            if (i.mod.needmoduleinfo)
            {
                //printf("module5 %s because of %s\n", sc.module.toChars(), mod.toChars());
                if (sc)
                    sc._module.needmoduleinfo = 1;
            }
        }
    }

    override void visit(Nspace ns)
    {
        if (ns.semanticRun >= PASSsemantic2)
            return;
        ns.semanticRun = PASSsemantic2;
        static if (LOG)
        {
            printf("+Nspace::semantic2('%s')\n", ns.toChars());
        }
        if (ns.members)
        {
            assert(sc);
            sc = sc.push(ns);
            sc.linkage = LINKcpp;
            foreach (s; *ns.members)
            {
                static if (LOG)
                {
                    printf("\tmember '%s', kind = '%s'\n", s.toChars(), s.kind());
                }
                s.semantic2(sc);
            }
            sc.pop();
        }
        static if (LOG)
        {
            printf("-Nspace::semantic2('%s')\n", ns.toChars());
        }
    }

    override void visit(AttribDeclaration ad)
    {
        Dsymbols* d = ad.include(sc, null);
        if (d)
        {
            Scope* sc2 = ad.newScope(sc);
            for (size_t i = 0; i < d.dim; i++)
            {
                Dsymbol s = (*d)[i];
                s.semantic2(sc2);
            }
            if (sc2 != sc)
                sc2.pop();
        }
    }

    /**
     * Run the DeprecatedDeclaration's semantic2 phase then its members.
     *
     * The message set via a `DeprecatedDeclaration` can be either of:
     * - a string literal
     * - an enum
     * - a static immutable
     * So we need to call ctfe to resolve it.
     * Afterward forwards to the members' semantic2.
     */
    override void visit(DeprecatedDeclaration dd)
    {
        getMessage(dd);
        visit(cast(AttribDeclaration)dd);
    }

    override void visit(AlignDeclaration ad)
    {
        ad.getAlignment(sc);
        visit(cast(AttribDeclaration)ad);
    }

    override void visit(UserAttributeDeclaration uad)
    {
        if (uad.decl && uad.atts && uad.atts.dim && uad._scope)
        {
            static void eval(Scope* sc, Expressions* exps)
            {
                foreach (ref Expression e; *exps)
                {
                    if (e)
                    {
                        e = e.expressionSemantic(sc);
                        if (definitelyValueParameter(e))
                            e = e.ctfeInterpret();
                        if (e.op == TOKtuple)
                        {
                            TupleExp te = cast(TupleExp)e;
                            eval(sc, te.exps);
                        }
                    }
                }
            }

            uad._scope = null;
            eval(sc, uad.atts);
        }
        visit(cast(AttribDeclaration)uad);
    }

    override void visit(AggregateDeclaration ad)
    {
        //printf("AggregateDeclaration::semantic2(%s) type = %s, errors = %d\n", toChars(), type.toChars(), errors);
        if (!ad.members)
            return;

        if (ad._scope)
        {
            ad.error("has forward references");
            return;
        }

        auto sc2 = ad.newScope(sc);

        ad.determineSize(ad.loc);

        for (size_t i = 0; i < ad.members.dim; i++)
        {
            Dsymbol s = (*ad.members)[i];
            //printf("\t[%d] %s\n", i, s.toChars());
            s.semantic2(sc2);
        }

        sc2.pop();
    }
}

structalign_t getAlignment(AlignDeclaration ad, Scope* sc)
{
    if (ad.salign != ad.UNKNOWN)
        return ad.salign;

    if (!ad.ealign)
        return ad.salign = STRUCTALIGN_DEFAULT;

    sc = sc.startCTFE();
    ad.ealign = ad.ealign.expressionSemantic(sc);
    ad.ealign = resolveProperties(sc, ad.ealign);
    sc = sc.endCTFE();
    ad.ealign = ad.ealign.ctfeInterpret();

    if (ad.ealign.op == TOKerror)
        return ad.salign = STRUCTALIGN_DEFAULT;

    Type tb = ad.ealign.type.toBasetype();
    auto n = ad.ealign.toInteger();

    if (n < 1 || n & (n - 1) || structalign_t.max < n || !tb.isintegral())
    {
        error(ad.loc, "alignment must be an integer positive power of 2, not %s", ad.ealign.toChars());
        return ad.salign = STRUCTALIGN_DEFAULT;
    }

    return ad.salign = cast(structalign_t)n;
}

const(char)* getMessage(DeprecatedDeclaration dd)
{
    if (auto sc = dd._scope)
    {
        dd._scope = null;

        sc = sc.startCTFE();
        dd.msg = dd.msg.expressionSemantic(sc);
        dd.msg = resolveProperties(sc, dd.msg);
        sc = sc.endCTFE();
        dd.msg = dd.msg.ctfeInterpret();

        if (auto se = dd.msg.toStringExp())
            dd.msgstr = se.toStringz().ptr;
        else
            dd.msg.error("compile time constant expected, not `%s`", dd.msg.toChars());
    }
    return dd.msgstr;
}

extern(C++) final class Semantic3Visitor : Visitor
{
    alias visit = super.visit;

    Scope* sc;
    this(Scope* sc)
    {
        this.sc = sc;
    }

    override void visit(Dsymbol) {}

    override void visit(TemplateInstance tempinst)
    {
        static if (LOG)
        {
            printf("TemplateInstance.semantic3('%s'), semanticRun = %d\n", tempinst.toChars(), tempinst.semanticRun);
        }
        //if (toChars()[0] == 'D') *(char*)0=0;
        if (tempinst.semanticRun >= PASSsemantic3)
            return;
        tempinst.semanticRun = PASSsemantic3;
        if (!tempinst.errors && tempinst.members)
        {
            TemplateDeclaration tempdecl = tempinst.tempdecl.isTemplateDeclaration();
            assert(tempdecl);

            sc = tempdecl._scope;
            sc = sc.push(tempinst.argsym);
            sc = sc.push(tempinst);
            sc.tinst = tempinst;
            sc.minst = tempinst.minst;

            int needGagging = (tempinst.gagged && !global.gag);
            uint olderrors = global.errors;
            int oldGaggedErrors = -1; // dead-store to prevent spurious warning
            /* If this is a gagged instantiation, gag errors.
             * Future optimisation: If the results are actually needed, errors
             * would already be gagged, so we don't really need to run semantic
             * on the members.
             */
            if (needGagging)
                oldGaggedErrors = global.startGagging();

            for (size_t i = 0; i < tempinst.members.dim; i++)
            {
                Dsymbol s = (*tempinst.members)[i];
                s.semantic3(sc);
                if (tempinst.gagged && global.errors != olderrors)
                    break;
            }

            if (global.errors != olderrors)
            {
                if (!tempinst.errors)
                {
                    if (!tempdecl.literal)
                        tempinst.error(tempinst.loc, "error instantiating");
                    if (tempinst.tinst)
                        tempinst.tinst.printInstantiationTrace();
                }
                tempinst.errors = true;
            }
            if (needGagging)
                global.endGagging(oldGaggedErrors);

            sc = sc.pop();
            sc.pop();
        }
    }

    override void visit(TemplateMixin tmix)
    {
        if (tmix.semanticRun >= PASSsemantic3)
            return;
        tmix.semanticRun = PASSsemantic3;
        static if (LOG)
        {
            printf("TemplateMixin.semantic3('%s')\n", tmix.toChars());
        }
        if (tmix.members)
        {
            sc = sc.push(tmix.argsym);
            sc = sc.push(tmix);
            for (size_t i = 0; i < tmix.members.dim; i++)
            {
                Dsymbol s = (*tmix.members)[i];
                s.semantic3(sc);
            }
            sc = sc.pop();
            sc.pop();
        }
    }

    override void visit(Module mod)
    {
        //printf("Module::semantic3('%s'): parent = %p\n", toChars(), parent);
        if (mod.semanticRun != PASSsemantic2done)
            return;
        mod.semanticRun = PASSsemantic3;
        // Note that modules get their own scope, from scratch.
        // This is so regardless of where in the syntax a module
        // gets imported, it is unaffected by context.
        Scope* sc = Scope.createGlobal(mod); // create root scope
        //printf("Module = %p\n", sc.scopesym);
        // Pass 3 semantic routines: do initializers and function bodies
        for (size_t i = 0; i < mod.members.dim; i++)
        {
            Dsymbol s = (*mod.members)[i];
            //printf("Module %s: %s.semantic3()\n", toChars(), s.toChars());
            s.semantic3(sc);

            mod.runDeferredSemantic2();
        }
        if (mod.userAttribDecl)
        {
            mod.userAttribDecl.semantic3(sc);
        }
        sc = sc.pop();
        sc.pop();
        mod.semanticRun = PASSsemantic3done;
    }

    override void visit(FuncDeclaration funcdecl)
    {
        VarDeclaration _arguments = null;

        if (!funcdecl.parent)
        {
            if (global.errors)
                return;
            //printf("FuncDeclaration::semantic3(%s '%s', sc = %p)\n", kind(), toChars(), sc);
            assert(0);
        }
        if (funcdecl.errors || isError(funcdecl.parent))
        {
            funcdecl.errors = true;
            return;
        }
        //printf("FuncDeclaration::semantic3('%s.%s', %p, sc = %p, loc = %s)\n", parent.toChars(), toChars(), this, sc, loc.toChars());
        //fflush(stdout);
        //printf("storage class = x%x %x\n", sc.stc, storage_class);
        //{ static int x; if (++x == 2) *(char*)0=0; }
        //printf("\tlinkage = %d\n", sc.linkage);

        if (funcdecl.ident == Id.assign && !funcdecl.inuse)
        {
            if (funcdecl.storage_class & STCinference)
            {
                /* https://issues.dlang.org/show_bug.cgi?id=15044
                 * For generated opAssign function, any errors
                 * from its body need to be gagged.
                 */
                uint oldErrors = global.startGagging();
                ++funcdecl.inuse;
                funcdecl.semantic3(sc);
                --funcdecl.inuse;
                if (global.endGagging(oldErrors))   // if errors happened
                {
                    // Disable generated opAssign, because some members forbid identity assignment.
                    funcdecl.storage_class |= STCdisable;
                    funcdecl.fbody = null;   // remove fbody which contains the error
                    funcdecl.semantic3Errors = false;
                }
                return;
            }
        }

        //printf(" sc.incontract = %d\n", (sc.flags & SCOPEcontract));
        if (funcdecl.semanticRun >= PASSsemantic3)
            return;
        funcdecl.semanticRun = PASSsemantic3;
        funcdecl.semantic3Errors = false;

        if (!funcdecl.type || funcdecl.type.ty != Tfunction)
            return;
        TypeFunction f = cast(TypeFunction)funcdecl.type;
        if (!funcdecl.inferRetType && f.next.ty == Terror)
            return;

        if (!funcdecl.fbody && funcdecl.inferRetType && !f.next)
        {
            funcdecl.error("has no function body with return type inference");
            return;
        }

        uint oldErrors = global.errors;

        if (funcdecl.frequire)
        {
            for (size_t i = 0; i < funcdecl.foverrides.dim; i++)
            {
                FuncDeclaration fdv = funcdecl.foverrides[i];
                if (fdv.fbody && !fdv.frequire)
                {
                    funcdecl.error("cannot have an in contract when overridden function %s does not have an in contract", fdv.toPrettyChars());
                    break;
                }
            }
        }

        // Remember whether we need to generate an 'out' contract.
        immutable bool needEnsure = FuncDeclaration.needsFensure(funcdecl);

        if (funcdecl.fbody || funcdecl.frequire || needEnsure)
        {
            /* Symbol table into which we place parameters and nested functions,
             * solely to diagnose name collisions.
             */
            funcdecl.localsymtab = new DsymbolTable();

            // Establish function scope
            auto ss = new ScopeDsymbol();
            // find enclosing scope symbol, might skip symbol-less CTFE and/or FuncExp scopes
            for (auto scx = sc; ; scx = scx.enclosing)
            {
                if (scx.scopesym)
                {
                    ss.parent = scx.scopesym;
                    break;
                }
            }
            ss.loc = funcdecl.loc;
            ss.endlinnum = funcdecl.endloc.linnum;
            Scope* sc2 = sc.push(ss);
            sc2.func = funcdecl;
            sc2.parent = funcdecl;
            sc2.callSuper = 0;
            sc2.sbreak = null;
            sc2.scontinue = null;
            sc2.sw = null;
            sc2.fes = funcdecl.fes;
            sc2.linkage = LINKd;
            sc2.stc &= ~(STCauto | STCscope | STCstatic | STCabstract | STCdeprecated | STCoverride | STC_TYPECTOR | STCfinal | STCtls | STCgshared | STCref | STCreturn | STCproperty | STCnothrow | STCpure | STCsafe | STCtrusted | STCsystem);
            sc2.protection = Prot(PROTpublic);
            sc2.explicitProtection = 0;
            sc2.aligndecl = null;
            if (funcdecl.ident != Id.require && funcdecl.ident != Id.ensure)
                sc2.flags = sc.flags & ~SCOPEcontract;
            sc2.flags &= ~SCOPEcompile;
            sc2.tf = null;
            sc2.os = null;
            sc2.noctor = 0;
            sc2.userAttribDecl = null;
            if (sc2.intypeof == 1)
                sc2.intypeof = 2;
            sc2.fieldinit = null;
            sc2.fieldinit_dim = 0;

            /* Note: When a lambda is defined immediately under aggregate member
             * scope, it should be contextless due to prevent interior pointers.
             * e.g.
             *      // dg points 'this' - it's interior pointer
             *      class C { int x; void delegate() dg = (){ this.x = 1; }; }
             *
             * However, lambdas could be used inside typeof, in order to check
             * some expressions validity at compile time. For such case the lambda
             * body can access aggregate instance members.
             * e.g.
             *      class C { int x; static assert(is(typeof({ this.x = 1; }))); }
             *
             * To properly accept it, mark these lambdas as member functions.
             */
            if (auto fld = funcdecl.isFuncLiteralDeclaration())
            {
                if (auto ad = funcdecl.isMember2())
                {
                    if (!sc.intypeof)
                    {
                        if (fld.tok == TOKdelegate)
                            funcdecl.error("cannot be %s members", ad.kind());
                        else
                            fld.tok = TOKfunction;
                    }
                    else
                    {
                        if (fld.tok != TOKfunction)
                            fld.tok = TOKdelegate;
                    }
                }
            }

            // Declare 'this'
            auto ad = funcdecl.isThis();
            funcdecl.vthis = funcdecl.declareThis(sc2, ad);
            //printf("[%s] ad = %p vthis = %p\n", loc.toChars(), ad, vthis);
            //if (vthis) printf("\tvthis.type = %s\n", vthis.type.toChars());

            // Declare hidden variable _arguments[] and _argptr
            if (f.varargs == 1)
            {
                if (f.linkage == LINKd)
                {
                    // Declare _arguments[]
                    funcdecl.v_arguments = new VarDeclaration(Loc(), Type.typeinfotypelist.type, Id._arguments_typeinfo, null);
                    funcdecl.v_arguments.storage_class |= STCtemp | STCparameter;
                    funcdecl.v_arguments.semantic(sc2);
                    sc2.insert(funcdecl.v_arguments);
                    funcdecl.v_arguments.parent = funcdecl;

                    //Type *t = Type::typeinfo.type.constOf().arrayOf();
                    Type t = Type.dtypeinfo.type.arrayOf();
                    _arguments = new VarDeclaration(Loc(), t, Id._arguments, null);
                    _arguments.storage_class |= STCtemp;
                    _arguments.semantic(sc2);
                    sc2.insert(_arguments);
                    _arguments.parent = funcdecl;
                }
                if (f.linkage == LINKd || (f.parameters && Parameter.dim(f.parameters)))
                {
                    // Declare _argptr
                    version (IN_LLVM)
                        Type t = Type.tvalist.typeSemantic(funcdecl.loc, sc);
                    else
                        Type t = Type.tvalist;
                    // Init is handled in FuncDeclaration_toObjFile
                    funcdecl.v_argptr = new VarDeclaration(Loc(), t, Id._argptr, new VoidInitializer(funcdecl.loc));
                    funcdecl.v_argptr.storage_class |= STCtemp;
                    funcdecl.v_argptr.semantic(sc2);
                    sc2.insert(funcdecl.v_argptr);
                    funcdecl.v_argptr.parent = funcdecl;
                }
            }

            version(IN_LLVM)
            {
                // Make sure semantic analysis has been run on argument types. This is
                // e.g. needed for TypeTuple!(int, int) to be picked up as two int
                // parameters by the Parameter functions.
                if (f.parameters)
                {
                    for (size_t i = 0; i < Parameter.dim(f.parameters); i++)
                    {
                        Parameter arg = Parameter.getNth(f.parameters, i);
                        Type nw = arg.type.typeSemantic(Loc(), sc);
                        if (arg.type != nw)
                        {
                            arg.type = nw;
                            // Examine this index again.
                            // This is important if it turned into a tuple.
                            // In particular, the empty tuple should be handled or the
                            // next parameter will be skipped.
                            // LDC_FIXME: Maybe we only need to do this for tuples,
                            //            and can add tuple.length after decrement?
                            i--;
                        }
                    }
                }
            }

            /* Declare all the function parameters as variables
             * and install them in parameters[]
             */
            size_t nparams = Parameter.dim(f.parameters);
            if (nparams)
            {
                /* parameters[] has all the tuples removed, as the back end
                 * doesn't know about tuples
                 */
                funcdecl.parameters = new VarDeclarations();
                funcdecl.parameters.reserve(nparams);
                for (size_t i = 0; i < nparams; i++)
                {
                    Parameter fparam = Parameter.getNth(f.parameters, i);
                    Identifier id = fparam.ident;
                    StorageClass stc = 0;
                    if (!id)
                    {
                        /* Generate identifier for un-named parameter,
                         * because we need it later on.
                         */
                        fparam.ident = id = Identifier.generateId("_param_", i);
                        stc |= STCtemp;
                    }
                    Type vtype = fparam.type;
                    auto v = new VarDeclaration(funcdecl.loc, vtype, id, null);
                    //printf("declaring parameter %s of type %s\n", v.toChars(), v.type.toChars());
                    stc |= STCparameter;
                    if (f.varargs == 2 && i + 1 == nparams)
                        stc |= STCvariadic;
                    if (funcdecl.flags & FUNCFLAGinferScope && !(fparam.storageClass & STCscope))
                        stc |= STCmaybescope;
                    stc |= fparam.storageClass & (STCin | STCout | STCref | STCreturn | STCscope | STClazy | STCfinal | STC_TYPECTOR | STCnodtor);
                    v.storage_class = stc;
                    v.semantic(sc2);
                    if (!sc2.insert(v))
                        funcdecl.error("parameter %s.%s is already defined", funcdecl.toChars(), v.toChars());
                    else
                        funcdecl.parameters.push(v);
                    funcdecl.localsymtab.insert(v);
                    v.parent = funcdecl;
                }
            }

            // Declare the tuple symbols and put them in the symbol table,
            // but not in parameters[].
            if (f.parameters)
            {
                for (size_t i = 0; i < f.parameters.dim; i++)
                {
                    Parameter fparam = (*f.parameters)[i];
                    if (!fparam.ident)
                        continue; // never used, so ignore
                    if (fparam.type.ty == Ttuple)
                    {
                        TypeTuple t = cast(TypeTuple)fparam.type;
                        size_t dim = Parameter.dim(t.arguments);
                        auto exps = new Objects();
                        exps.setDim(dim);
                        for (size_t j = 0; j < dim; j++)
                        {
                            Parameter narg = Parameter.getNth(t.arguments, j);
                            assert(narg.ident);
                            VarDeclaration v = sc2.search(Loc(), narg.ident, null).isVarDeclaration();
                            assert(v);
                            Expression e = new VarExp(v.loc, v);
                            (*exps)[j] = e;
                        }
                        assert(fparam.ident);
                        auto v = new TupleDeclaration(funcdecl.loc, fparam.ident, exps);
                        //printf("declaring tuple %s\n", v.toChars());
                        v.isexp = true;
                        if (!sc2.insert(v))
                            funcdecl.error("parameter %s.%s is already defined", funcdecl.toChars(), v.toChars());
                        funcdecl.localsymtab.insert(v);
                        v.parent = funcdecl;
                    }
                }
            }

            // Precondition invariant
            Statement fpreinv = null;
            if (funcdecl.addPreInvariant())
            {
                Expression e = addInvariant(funcdecl.loc, sc, ad, funcdecl.vthis);
                if (e)
                    fpreinv = new ExpStatement(Loc(), e);
            }

            // Postcondition invariant
            Statement fpostinv = null;
            if (funcdecl.addPostInvariant())
            {
                Expression e = addInvariant(funcdecl.loc, sc, ad, funcdecl.vthis);
                if (e)
                    fpostinv = new ExpStatement(Loc(), e);
            }

            // Pre/Postcondition contract
            if (!funcdecl.fbody)
                funcdecl.buildEnsureRequire();

            Scope* scout = null;
            if (needEnsure || funcdecl.addPostInvariant())
            {
                /* https://issues.dlang.org/show_bug.cgi?id=3657
                 * Set the correct end line number for fensure scope.
                 */
                uint fensure_endlin = funcdecl.endloc.linnum;
                if (funcdecl.fensure)
                    if (auto s = funcdecl.fensure.isScopeStatement())
                        fensure_endlin = s.endloc.linnum;

                if ((needEnsure && global.params.useOut) || fpostinv)
                {
                    funcdecl.returnLabel = new LabelDsymbol(Id.returnLabel);
                }

                // scope of out contract (need for vresult.semantic)
                auto sym = new ScopeDsymbol();
                sym.parent = sc2.scopesym;
                sym.loc = funcdecl.loc;
                sym.endlinnum = fensure_endlin;
                scout = sc2.push(sym);
            }

            if (funcdecl.fbody)
            {
                auto sym = new ScopeDsymbol();
                sym.parent = sc2.scopesym;
                sym.loc = funcdecl.loc;
                sym.endlinnum = funcdecl.endloc.linnum;
                sc2 = sc2.push(sym);

                auto ad2 = funcdecl.isMember2();

                /* If this is a class constructor
                 */
                if (ad2 && funcdecl.isCtorDeclaration())
                {
                    sc2.allocFieldinit(ad2.fields.dim);
                    foreach (v; ad2.fields)
                    {
                        v.ctorinit = 0;
                    }
                }

                if (!funcdecl.inferRetType && retStyle(f) != RETstack)
                    funcdecl.nrvo_can = 0;

                bool inferRef = (f.isref && (funcdecl.storage_class & STCauto));

                funcdecl.fbody = funcdecl.fbody.statementSemantic(sc2);
                if (!funcdecl.fbody)
                    funcdecl.fbody = new CompoundStatement(Loc(), new Statements());

                if (funcdecl.naked)
                {
                    fpreinv = null;         // can't accommodate with no stack frame
                    fpostinv = null;
                }

                assert(funcdecl.type == f || (funcdecl.type.ty == Tfunction && f.purity == PUREimpure && (cast(TypeFunction)funcdecl.type).purity >= PUREfwdref));
                f = cast(TypeFunction)funcdecl.type;

                if (funcdecl.inferRetType)
                {
                    // If no return type inferred yet, then infer a void
                    if (!f.next)
                        f.next = Type.tvoid;
                    if (f.checkRetType(funcdecl.loc))
                        funcdecl.fbody = new ErrorStatement();
                }
                if (global.params.vcomplex && f.next !is null)
                    f.next.checkComplexTransition(funcdecl.loc);

                if (funcdecl.returns && !funcdecl.fbody.isErrorStatement())
                {
                    for (size_t i = 0; i < funcdecl.returns.dim;)
                    {
                        Expression exp = (*funcdecl.returns)[i].exp;
                        if (exp.op == TOKvar && (cast(VarExp)exp).var == funcdecl.vresult)
                        {
                            if (f.next.ty == Tvoid && funcdecl.isMain())
                                exp.type = Type.tint32;
                            else
                                exp.type = f.next;
                            // Remove `return vresult;` from returns
                            funcdecl.returns.remove(i);
                            continue;
                        }
                        if (inferRef && f.isref && !exp.type.constConv(f.next)) // https://issues.dlang.org/show_bug.cgi?id=13336
                            f.isref = false;
                        i++;
                    }
                }
                if (f.isref) // Function returns a reference
                {
                    if (funcdecl.storage_class & STCauto)
                        funcdecl.storage_class &= ~STCauto;
                }
                if (retStyle(f) != RETstack)
                    funcdecl.nrvo_can = 0;

                if (funcdecl.fbody.isErrorStatement())
                {
                }
                else if (funcdecl.isStaticCtorDeclaration())
                {
                    /* It's a static constructor. Ensure that all
                     * ctor consts were initialized.
                     */
                    ScopeDsymbol pd = funcdecl.toParent().isScopeDsymbol();
                    for (size_t i = 0; i < pd.members.dim; i++)
                    {
                        Dsymbol s = (*pd.members)[i];
                        s.checkCtorConstInit();
                    }
                }
                else if (ad2 && funcdecl.isCtorDeclaration())
                {
                    ClassDeclaration cd = ad2.isClassDeclaration();

                    // Verify that all the ctorinit fields got initialized
                    if (!(sc2.callSuper & CSXthis_ctor))
                    {
                        foreach (i, v; ad2.fields)
                        {
                            if (v.isThisDeclaration())
                                continue;
                            if (v.ctorinit == 0)
                            {
                                /* Current bugs in the flow analysis:
                                 * 1. union members should not produce error messages even if
                                 *    not assigned to
                                 * 2. structs should recognize delegating opAssign calls as well
                                 *    as delegating calls to other constructors
                                 */
                                if (v.isCtorinit() && !v.type.isMutable() && cd)
                                    funcdecl.error("missing initializer for %s field %s", MODtoChars(v.type.mod), v.toChars());
                                else if (v.storage_class & STCnodefaultctor)
                                    error(funcdecl.loc, "field %s must be initialized in constructor", v.toChars());
                                else if (v.type.needsNested())
                                    error(funcdecl.loc, "field %s must be initialized in constructor, because it is nested struct", v.toChars());
                            }
                            else
                            {
                                bool mustInit = (v.storage_class & STCnodefaultctor || v.type.needsNested());
                                if (mustInit && !(sc2.fieldinit[i] & CSXthis_ctor))
                                {
                                    funcdecl.error("field %s must be initialized but skipped", v.toChars());
                                }
                            }
                        }
                    }
                    sc2.freeFieldinit();

                    if (cd && !(sc2.callSuper & CSXany_ctor) && cd.baseClass && cd.baseClass.ctor)
                    {
                        sc2.callSuper = 0;

                        // Insert implicit super() at start of fbody
                        FuncDeclaration fd = resolveFuncCall(Loc(), sc2, cd.baseClass.ctor, null, funcdecl.vthis.type, null, 1);
                        if (!fd)
                        {
                            funcdecl.error("no match for implicit super() call in constructor");
                        }
                        else if (fd.storage_class & STCdisable)
                        {
                            funcdecl.error("cannot call super() implicitly because it is annotated with @disable");
                        }
                        else
                        {
                            Expression e1 = new SuperExp(Loc());
                            Expression e = new CallExp(Loc(), e1);
                            e = e.expressionSemantic(sc2);
                            Statement s = new ExpStatement(Loc(), e);
                            funcdecl.fbody = new CompoundStatement(Loc(), s, funcdecl.fbody);
                        }
                    }
                    //printf("callSuper = x%x\n", sc2.callSuper);
                }

                /* https://issues.dlang.org/show_bug.cgi?id=17502
                 * Wait until after the return type has been inferred before
                 * generating the contracts for this function, and merging contracts
                 * from overrides.
                 *
                 * https://issues.dlang.org/show_bug.cgi?id=17893
                 * However should take care to generate this before inferered
                 * function attributes are applied, such as 'nothrow'.
                 *
                 * This was originally at the end of the first semantic pass, but
                 * required a fix-up to be done here for the '__result' variable
                 * type of __ensure() inside auto functions, but this didn't work
                 * if the out parameter was implicit.
                 */
                funcdecl.buildEnsureRequire();

                int blockexit = BEnone;
                if (!funcdecl.fbody.isErrorStatement())
                {
                    // Check for errors related to 'nothrow'.
                    uint nothrowErrors = global.errors;
                    blockexit = funcdecl.fbody.blockExit(funcdecl, f.isnothrow);
                    if (f.isnothrow && (global.errors != nothrowErrors))
                        error(funcdecl.loc, "nothrow %s `%s` may throw", funcdecl.kind(), funcdecl.toPrettyChars());
                    if (funcdecl.flags & FUNCFLAGnothrowInprocess)
                    {
                        if (funcdecl.type == f)
                            f = cast(TypeFunction)f.copy();
                        f.isnothrow = !(blockexit & BEthrow);
                    }
                }

                if (funcdecl.fbody.isErrorStatement())
                {
                }
                else if (ad2 && funcdecl.isCtorDeclaration())
                {
                    /* Append:
                     *  return this;
                     * to function body
                     */
                    if (blockexit & BEfallthru)
                    {
                        Statement s = new ReturnStatement(funcdecl.loc, null);
                        s = s.statementSemantic(sc2);
                        funcdecl.fbody = new CompoundStatement(funcdecl.loc, funcdecl.fbody, s);
                        funcdecl.hasReturnExp |= (funcdecl.hasReturnExp & 1 ? 16 : 1);
                    }
                }
                else if (funcdecl.fes)
                {
                    // For foreach(){} body, append a return 0;
                    if (blockexit & BEfallthru)
                    {
                        Expression e = new IntegerExp(0);
                        Statement s = new ReturnStatement(Loc(), e);
                        funcdecl.fbody = new CompoundStatement(Loc(), funcdecl.fbody, s);
                        funcdecl.hasReturnExp |= (funcdecl.hasReturnExp & 1 ? 16 : 1);
                    }
                    assert(!funcdecl.returnLabel);
                }
                else
                {
                    const(bool) inlineAsm = (funcdecl.hasReturnExp & 8) != 0;
                    if ((blockexit & BEfallthru) && f.next.ty != Tvoid && !inlineAsm)
                    {
                        Expression e;
                        if (!funcdecl.hasReturnExp)
                            funcdecl.error("has no return statement, but is expected to return a value of type %s", f.next.toChars());
                        else
                            funcdecl.error("no return exp; or assert(0); at end of function");
                        if (global.params.useAssert && !global.params.useInline)
                        {
                            /* Add an assert(0, msg); where the missing return
                             * should be.
                             */
                            e = new AssertExp(funcdecl.endloc, new IntegerExp(0), new StringExp(funcdecl.loc, cast(char*)"missing return expression"));
                        }
                        else
                            e = new HaltExp(funcdecl.endloc);
                        e = new CommaExp(Loc(), e, f.next.defaultInit());
                        e = e.expressionSemantic(sc2);
                        Statement s = new ExpStatement(Loc(), e);
                        funcdecl.fbody = new CompoundStatement(Loc(), funcdecl.fbody, s);
                    }
                }

                if (funcdecl.returns)
                {
                    bool implicit0 = (f.next.ty == Tvoid && funcdecl.isMain());
                    Type tret = implicit0 ? Type.tint32 : f.next;
                    assert(tret.ty != Tvoid);
                    if (funcdecl.vresult || funcdecl.returnLabel)
                        funcdecl.buildResultVar(scout ? scout : sc2, tret);

                    /* Cannot move this loop into NrvoWalker, because
                     * returns[i] may be in the nested delegate for foreach-body.
                     */
                    for (size_t i = 0; i < funcdecl.returns.dim; i++)
                    {
                        ReturnStatement rs = (*funcdecl.returns)[i];
                        Expression exp = rs.exp;
                        if (exp.op == TOKerror)
                            continue;
                        if (tret.ty == Terror)
                        {
                            // https://issues.dlang.org/show_bug.cgi?id=13702
                            exp = checkGC(sc2, exp);
                            continue;
                        }

                        if (!exp.implicitConvTo(tret) && funcdecl.isTypeIsolated(exp.type))
                        {
                            if (exp.type.immutableOf().implicitConvTo(tret))
                                exp = exp.castTo(sc2, exp.type.immutableOf());
                            else if (exp.type.wildOf().implicitConvTo(tret))
                                exp = exp.castTo(sc2, exp.type.wildOf());
                        }
                        exp = exp.implicitCastTo(sc2, tret);

                        if (f.isref)
                        {
                            // Function returns a reference
                            exp = exp.toLvalue(sc2, exp);
                            checkReturnEscapeRef(sc2, exp, false);
                        }
                        else
                        {
                            exp = exp.optimize(WANTvalue);

                            /* https://issues.dlang.org/show_bug.cgi?id=10789
                             * If NRVO is not possible, all returned lvalues should call their postblits.
                             */
                            if (!funcdecl.nrvo_can)
                                exp = doCopyOrMove(sc2, exp);

                            if (tret.hasPointers())
                                checkReturnEscape(sc2, exp, false);
                        }

                        exp = checkGC(sc2, exp);

                        if (funcdecl.vresult)
                        {
                            // Create: return vresult = exp;
                            exp = new BlitExp(rs.loc, funcdecl.vresult, exp);
                            exp.type = funcdecl.vresult.type;

                            if (rs.caseDim)
                                exp = Expression.combine(exp, new IntegerExp(rs.caseDim));
                        }
                        else if (funcdecl.tintro && !tret.equals(funcdecl.tintro.nextOf()))
                        {
                            exp = exp.implicitCastTo(sc2, funcdecl.tintro.nextOf());
                        }
                        rs.exp = exp;
                    }
                }
                if (funcdecl.nrvo_var || funcdecl.returnLabel)
                {
                    scope NrvoWalker nw = new NrvoWalker();
                    nw.fd = funcdecl;
                    nw.sc = sc2;
                    nw.visitStmt(funcdecl.fbody);
                }

                sc2 = sc2.pop();
            }

            funcdecl.frequire = funcdecl.mergeFrequire(funcdecl.frequire);
            funcdecl.fensure = funcdecl.mergeFensure(funcdecl.fensure, funcdecl.outId);

            Statement freq = funcdecl.frequire;
            Statement fens = funcdecl.fensure;

            /* Do the semantic analysis on the [in] preconditions and
             * [out] postconditions.
             */
            if (freq)
            {
                /* frequire is composed of the [in] contracts
                 */
                auto sym = new ScopeDsymbol();
                sym.parent = sc2.scopesym;
                sym.loc = funcdecl.loc;
                sym.endlinnum = funcdecl.endloc.linnum;
                sc2 = sc2.push(sym);
                sc2.flags = (sc2.flags & ~SCOPEcontract) | SCOPErequire;

                // BUG: need to error if accessing out parameters
                // BUG: need to treat parameters as const
                // BUG: need to disallow returns and throws
                // BUG: verify that all in and ref parameters are read
                freq = freq.statementSemantic(sc2);
                freq.blockExit(funcdecl, false);

                sc2 = sc2.pop();

                if (!global.params.useIn)
                    freq = null;
            }
            if (fens)
            {
                /* fensure is composed of the [out] contracts
                 */
                if (f.next.ty == Tvoid && funcdecl.outId)
                    funcdecl.error("void functions have no result");

                sc2 = scout; //push
                sc2.flags = (sc2.flags & ~SCOPEcontract) | SCOPEensure;

                // BUG: need to treat parameters as const
                // BUG: need to disallow returns and throws

                if (funcdecl.fensure && f.next.ty != Tvoid)
                    funcdecl.buildResultVar(scout, f.next);

                fens = fens.statementSemantic(sc2);
                fens.blockExit(funcdecl, false);

                sc2 = sc2.pop();

                if (!global.params.useOut)
                    fens = null;
            }
            if (funcdecl.fbody && funcdecl.fbody.isErrorStatement())
            {
            }
            else
            {
                auto a = new Statements();
                // Merge in initialization of 'out' parameters
                if (funcdecl.parameters)
                {
                    for (size_t i = 0; i < funcdecl.parameters.dim; i++)
                    {
                        VarDeclaration v = (*funcdecl.parameters)[i];
                        if (v.storage_class & STCout)
                        {
                            assert(v._init);
                            ExpInitializer ie = v._init.isExpInitializer();
                            assert(ie);
                            if (ie.exp.op == TOKconstruct)
                                ie.exp.op = TOKassign; // construction occurred in parameter processing
                            a.push(new ExpStatement(Loc(), ie.exp));
                        }
                    }
                }

// we'll handle variadics ourselves
static if (!IN_LLVM)
{
                if (_arguments)
                {
                    /* Advance to elements[] member of TypeInfo_Tuple with:
                     *  _arguments = v_arguments.elements;
                     */
                    Expression e = new VarExp(Loc(), funcdecl.v_arguments);
                    e = new DotIdExp(Loc(), e, Id.elements);
                    e = new ConstructExp(Loc(), _arguments, e);
                    e = e.expressionSemantic(sc2);

                    _arguments._init = new ExpInitializer(Loc(), e);
                    auto de = new DeclarationExp(Loc(), _arguments);
                    a.push(new ExpStatement(Loc(), de));
                }
}

                // Merge contracts together with body into one compound statement

                if (freq || fpreinv)
                {
                    if (!freq)
                        freq = fpreinv;
                    else if (fpreinv)
                        freq = new CompoundStatement(Loc(), freq, fpreinv);

                    a.push(freq);
                }

                if (funcdecl.fbody)
                    a.push(funcdecl.fbody);

                if (fens || fpostinv)
                {
                    if (!fens)
                        fens = fpostinv;
                    else if (fpostinv)
                        fens = new CompoundStatement(Loc(), fpostinv, fens);

                    auto ls = new LabelStatement(Loc(), Id.returnLabel, fens);
                    funcdecl.returnLabel.statement = ls;
                    a.push(funcdecl.returnLabel.statement);

                    if (f.next.ty != Tvoid && funcdecl.vresult)
                    {
version(IN_LLVM)
{
                        Expression e = null;
                        if (funcdecl.isCtorDeclaration())
                        {
                            ThisExp te = new ThisExp(Loc());
                            te.type = funcdecl.vthis.type;
                            te.var = funcdecl.vthis;
                            e = te;
                        }
                        else
                        {
                            e = new VarExp(Loc(), funcdecl.vresult);
                        }
}
else
{
                        // Create: return vresult;
                        Expression e = new VarExp(Loc(), funcdecl.vresult);
}
                        if (funcdecl.tintro)
                        {
                            e = e.implicitCastTo(sc, funcdecl.tintro.nextOf());
                            e = e.expressionSemantic(sc);
                        }
                        auto s = new ReturnStatement(Loc(), e);
                        a.push(s);
                    }
                }
                if (funcdecl.isMain() && f.next.ty == Tvoid)
                {
                    // Add a return 0; statement
                    Statement s = new ReturnStatement(Loc(), new IntegerExp(0));
                    a.push(s);
                }

                Statement sbody = new CompoundStatement(Loc(), a);

                /* Append destructor calls for parameters as finally blocks.
                 */
                if (funcdecl.parameters)
                {
                    foreach (v; *funcdecl.parameters)
                    {
                        if (v.storage_class & (STCref | STCout | STClazy))
                            continue;
                        if (v.needsScopeDtor())
                        {
                            // same with ExpStatement.scopeCode()
                            Statement s = new DtorExpStatement(Loc(), v.edtor, v);
                            v.storage_class |= STCnodtor;

                            s = s.statementSemantic(sc2);

                            bool isnothrow = f.isnothrow & !(funcdecl.flags & FUNCFLAGnothrowInprocess);
                            int blockexit = s.blockExit(funcdecl, isnothrow);
                            if (f.isnothrow && isnothrow && blockexit & BEthrow)
                                error(funcdecl.loc, "nothrow %s `%s` may throw", funcdecl.kind(), funcdecl.toPrettyChars());
                            if (funcdecl.flags & FUNCFLAGnothrowInprocess && blockexit & BEthrow)
                                f.isnothrow = false;

                            if (sbody.blockExit(funcdecl, f.isnothrow) == BEfallthru)
                                sbody = new CompoundStatement(Loc(), sbody, s);
                            else
                                sbody = new TryFinallyStatement(Loc(), sbody, s);
                        }
                    }
                }
                // from this point on all possible 'throwers' are checked
                funcdecl.flags &= ~FUNCFLAGnothrowInprocess;

                if (funcdecl.isSynchronized())
                {
                    /* Wrap the entire function body in a synchronized statement
                     */
                    ClassDeclaration cd = funcdecl.isThis() ? funcdecl.isThis().isClassDeclaration() : funcdecl.parent.isClassDeclaration();
                    if (cd)
                    {
                        if (!global.params.is64bit && global.params.isWindows && !funcdecl.isStatic() && !sbody.usesEH() && !global.params.trace)
                        {
                            /* The back end uses the "jmonitor" hack for syncing;
                             * no need to do the sync at this level.
                             */
                        }
                        else
                        {
                            Expression vsync;
                            if (funcdecl.isStatic())
                            {
                                // The monitor is in the ClassInfo
                                vsync = new DotIdExp(funcdecl.loc, resolve(funcdecl.loc, sc2, cd, false), Id.classinfo);
                            }
                            else
                            {
                                // 'this' is the monitor
                                vsync = new VarExp(funcdecl.loc, funcdecl.vthis);
                            }
                            sbody = new PeelStatement(sbody); // don't redo semantic()
                            sbody = new SynchronizedStatement(funcdecl.loc, vsync, sbody);
                            sbody = sbody.statementSemantic(sc2);
                        }
                    }
                    else
                    {
                        funcdecl.error("synchronized function %s must be a member of a class", funcdecl.toChars());
                    }
                }

                // If declaration has no body, don't set sbody to prevent incorrect codegen.
                InterfaceDeclaration id = funcdecl.parent.isInterfaceDeclaration();
                if (funcdecl.fbody || id && (funcdecl.fdensure || funcdecl.fdrequire) && funcdecl.isVirtual())
                    funcdecl.fbody = sbody;
            }

            // Fix up forward-referenced gotos
            if (funcdecl.gotos)
            {
                for (size_t i = 0; i < funcdecl.gotos.dim; ++i)
                {
                    (*funcdecl.gotos)[i].checkLabel();
                }
            }

            if (funcdecl.naked && (funcdecl.fensure || funcdecl.frequire))
                funcdecl.error("naked assembly functions with contracts are not supported");

            sc2.callSuper = 0;
            sc2.pop();
        }

        if (funcdecl.checkClosure())
        {
            // We should be setting errors here instead of relying on the global error count.
            //errors = true;
        }

        /* If function survived being marked as impure, then it is pure
         */
        if (funcdecl.flags & FUNCFLAGpurityInprocess)
        {
            funcdecl.flags &= ~FUNCFLAGpurityInprocess;
            if (funcdecl.type == f)
                f = cast(TypeFunction)f.copy();
            f.purity = PUREfwdref;
        }

        if (funcdecl.flags & FUNCFLAGsafetyInprocess)
        {
            funcdecl.flags &= ~FUNCFLAGsafetyInprocess;
            if (funcdecl.type == f)
                f = cast(TypeFunction)f.copy();
            f.trust = TRUSTsafe;
        }

        if (funcdecl.flags & FUNCFLAGnogcInprocess)
        {
            funcdecl.flags &= ~FUNCFLAGnogcInprocess;
            if (funcdecl.type == f)
                f = cast(TypeFunction)f.copy();
            f.isnogc = true;
        }

        if (funcdecl.flags & FUNCFLAGreturnInprocess)
        {
            funcdecl.flags &= ~FUNCFLAGreturnInprocess;
            if (funcdecl.storage_class & STCreturn)
            {
                if (funcdecl.type == f)
                    f = cast(TypeFunction)f.copy();
                f.isreturn = true;
            }
        }

        funcdecl.flags &= ~FUNCFLAGinferScope;

        // Infer STCscope
        if (funcdecl.parameters)
        {
            size_t nfparams = Parameter.dim(f.parameters);
            assert(nfparams == funcdecl.parameters.dim);
            foreach (u, v; *funcdecl.parameters)
            {
                if (v.storage_class & STCmaybescope)
                {
                    //printf("Inferring scope for %s\n", v.toChars());
                    Parameter p = Parameter.getNth(f.parameters, u);
                    v.storage_class &= ~STCmaybescope;
                    v.storage_class |= STCscope | STCscopeinferred;
                    p.storageClass |= STCscope | STCscopeinferred;
                    assert(!(p.storageClass & STCmaybescope));
                }
            }
        }

        if (funcdecl.vthis && funcdecl.vthis.storage_class & STCmaybescope)
        {
            funcdecl.vthis.storage_class &= ~STCmaybescope;
            funcdecl.vthis.storage_class |= STCscope | STCscopeinferred;
            f.isscope = true;
            f.isscopeinferred = true;
        }

        // reset deco to apply inference result to mangled name
        if (f != funcdecl.type)
            f.deco = null;

        // Do semantic type AFTER pure/nothrow inference.
        if (!f.deco && funcdecl.ident != Id.xopEquals && funcdecl.ident != Id.xopCmp)
        {
            sc = sc.push();
            if (funcdecl.isCtorDeclaration()) // https://issues.dlang.org/show_bug.cgi?id=#15665
                sc.flags |= SCOPEctor;
            sc.stc = 0;
            sc.linkage = funcdecl.linkage; // https://issues.dlang.org/show_bug.cgi?id=8496
            funcdecl.type = f.typeSemantic(funcdecl.loc, sc);
            sc = sc.pop();
        }

        /* If this function had instantiated with gagging, error reproduction will be
         * done by TemplateInstance::semantic.
         * Otherwise, error gagging should be temporarily ungagged by functionSemantic3.
         */
        funcdecl.semanticRun = PASSsemantic3done;
        funcdecl.semantic3Errors = (global.errors != oldErrors) || (funcdecl.fbody && funcdecl.fbody.isErrorStatement());
        if (funcdecl.type.ty == Terror)
            funcdecl.errors = true;
        //printf("-FuncDeclaration::semantic3('%s.%s', sc = %p, loc = %s)\n", parent.toChars(), toChars(), sc, loc.toChars());
        //fflush(stdout);
    }

    override void visit(Nspace ns)
    {
        if (ns.semanticRun >= PASSsemantic3)
            return;
        ns.semanticRun = PASSsemantic3;
        static if (LOG)
        {
            printf("Nspace::semantic3('%s')\n", ns.toChars());
        }
        if (ns.members)
        {
            sc = sc.push(ns);
            sc.linkage = LINKcpp;
            foreach (s; *ns.members)
            {
                s.semantic3(sc);
            }
            sc.pop();
        }
    }

    override void visit(AttribDeclaration ad)
    {
        Dsymbols* d = ad.include(sc, null);
        if (d)
        {
            Scope* sc2 = ad.newScope(sc);
            for (size_t i = 0; i < d.dim; i++)
            {
                Dsymbol s = (*d)[i];
                s.semantic3(sc2);
            }
            if (sc2 != sc)
                sc2.pop();
        }
    }

    override void visit(AggregateDeclaration ad)
    {
        //printf("AggregateDeclaration::semantic3(sc=%p, %s) type = %s, errors = %d\n", sc, toChars(), type.toChars(), errors);
        if (!ad.members)
            return;

        StructDeclaration sd = ad.isStructDeclaration();
        if (!sc) // from runDeferredSemantic3 for TypeInfo generation
        {
            assert(sd);
            sd.semanticTypeInfoMembers();
            return;
        }

        auto sc2 = ad.newScope(sc);

        for (size_t i = 0; i < ad.members.dim; i++)
        {
            Dsymbol s = (*ad.members)[i];
            s.semantic3(sc2);
        }

        sc2.pop();

        // don't do it for unused deprecated types
        // or error ypes
        if (!ad.getRTInfo && Type.rtinfo && (!ad.isDeprecated() || global.params.useDeprecated) && (ad.type && ad.type.ty != Terror))
        {
            // Evaluate: RTinfo!type
            auto tiargs = new Objects();
            tiargs.push(ad.type);
            auto ti = new TemplateInstance(ad.loc, Type.rtinfo, tiargs);

            Scope* sc3 = ti.tempdecl._scope.startCTFE();
            sc3.tinst = sc.tinst;
            sc3.minst = sc.minst;
            if (ad.isDeprecated())
                sc3.stc |= STCdeprecated;

            ti.semantic(sc3);
            ti.semantic2(sc3);
            ti.semantic3(sc3);
            auto e = resolve(Loc(), sc3, ti.toAlias(), false);

            sc3.endCTFE();

            e = e.ctfeInterpret();
            ad.getRTInfo = e;
        }
        if (sd)
            sd.semanticTypeInfoMembers();
        ad.semanticRun = PASSsemantic3done;
    }
}

private extern(C++) final class DsymbolSemanticVisitor : Visitor
{
    alias visit = super.visit;

    Scope* sc;
    this(Scope* sc)
    {
        this.sc = sc;
    }

    override void visit(Dsymbol dsym)
    {
        dsym.error("%p has no semantic routine", dsym);
    }

    override void visit(ScopeDsymbol) { }
    override void visit(Declaration) { }

    override void visit(AliasThis dsym)
    {
        if (dsym.semanticRun != PASSinit)
            return;

        if (dsym._scope)
        {
            sc = dsym._scope;
            dsym._scope = null;
        }

        if (!sc)
            return;

        dsym.semanticRun = PASSsemantic;

        Dsymbol p = sc.parent.pastMixin();
        AggregateDeclaration ad = p.isAggregateDeclaration();
        if (!ad)
        {
            error(dsym.loc, "alias this can only be a member of aggregate, not %s `%s`", p.kind(), p.toChars());
            return;
        }

        assert(ad.members);
        Dsymbol s = ad.search(dsym.loc, dsym.ident);
        if (!s)
        {
            s = sc.search(dsym.loc, dsym.ident, null);
            if (s)
                error(dsym.loc, "`%s` is not a member of `%s`", s.toChars(), ad.toChars());
            else
                error(dsym.loc, "undefined identifier `%s`", dsym.ident.toChars());
            return;
        }
        if (ad.aliasthis && s != ad.aliasthis)
        {
            error(dsym.loc, "there can be only one alias this");
            return;
        }

        /* disable the alias this conversion so the implicit conversion check
         * doesn't use it.
         */
        ad.aliasthis = null;

        Dsymbol sx = s;
        if (sx.isAliasDeclaration())
            sx = sx.toAlias();
        Declaration d = sx.isDeclaration();
        if (d && !d.isTupleDeclaration())
        {
            Type t = d.type;
            assert(t);
            if (ad.type.implicitConvTo(t) > MATCH.nomatch)
            {
                error(dsym.loc, "alias this is not reachable as `%s` already converts to `%s`", ad.toChars(), t.toChars());
            }
        }

        ad.aliasthis = s;
        dsym.semanticRun = PASSsemanticdone;
    }

    override void visit(AliasDeclaration dsym)
    {
        if (dsym.semanticRun >= PASSsemanticdone)
            return;
        assert(dsym.semanticRun <= PASSsemantic);

        dsym.storage_class |= sc.stc & STCdeprecated;
        dsym.protection = sc.protection;
        dsym.userAttribDecl = sc.userAttribDecl;

        if (!sc.func && dsym.inNonRoot())
            return;

        aliasSemantic(dsym, sc);
    }

    override void visit(VarDeclaration dsym)
    {
        version (none)
        {
            printf("VarDeclaration::semantic('%s', parent = '%s') sem = %d\n", toChars(), sc.parent ? sc.parent.toChars() : null, sem);
            printf(" type = %s\n", type ? type.toChars() : "null");
            printf(" stc = x%x\n", sc.stc);
            printf(" storage_class = x%llx\n", storage_class);
            printf("linkage = %d\n", sc.linkage);
            //if (strcmp(toChars(), "mul") == 0) assert(0);
        }
        //if (semanticRun > PASSinit)
        //    return;
        //semanticRun = PSSsemantic;

        if (dsym.semanticRun >= PASSsemanticdone)
            return;

        Scope* scx = null;
        if (dsym._scope)
        {
            sc = dsym._scope;
            scx = sc;
            dsym._scope = null;
        }

        if (!sc)
            return;

        dsym.semanticRun = PASSsemantic;

        /* Pick up storage classes from context, but except synchronized,
         * override, abstract, and final.
         */
        dsym.storage_class |= (sc.stc & ~(STCsynchronized | STCoverride | STCabstract | STCfinal));
        if (dsym.storage_class & STCextern && dsym._init)
            dsym.error("extern symbols cannot have initializers");

        dsym.userAttribDecl = sc.userAttribDecl;

        AggregateDeclaration ad = dsym.isThis();
        if (ad)
            dsym.storage_class |= ad.storage_class & STC_TYPECTOR;

        /* If auto type inference, do the inference
         */
        int inferred = 0;
        if (!dsym.type)
        {
            dsym.inuse++;

            // Infering the type requires running semantic,
            // so mark the scope as ctfe if required
            bool needctfe = (dsym.storage_class & (STCmanifest | STCstatic)) != 0;
            if (needctfe)
                sc = sc.startCTFE();

            //printf("inferring type for %s with init %s\n", toChars(), _init.toChars());
            dsym._init = dsym._init.inferType(sc);
            dsym.type = dsym._init.initializerToExpression().type;
            if (needctfe)
                sc = sc.endCTFE();

            dsym.inuse--;
            inferred = 1;

            /* This is a kludge to support the existing syntax for RAII
             * declarations.
             */
            dsym.storage_class &= ~STCauto;
            dsym.originalType = dsym.type.syntaxCopy();
        }
        else
        {
            if (!dsym.originalType)
                dsym.originalType = dsym.type.syntaxCopy();

            /* Prefix function attributes of variable declaration can affect
             * its type:
             *      pure nothrow void function() fp;
             *      static assert(is(typeof(fp) == void function() pure nothrow));
             */
            Scope* sc2 = sc.push();
            sc2.stc |= (dsym.storage_class & STC_FUNCATTR);
            dsym.inuse++;
            dsym.type = dsym.type.typeSemantic(dsym.loc, sc2);
            dsym.inuse--;
            sc2.pop();
        }
        //printf(" semantic type = %s\n", type ? type.toChars() : "null");
        if (dsym.type.ty == Terror)
            dsym.errors = true;

        dsym.type.checkDeprecated(dsym.loc, sc);
        dsym.linkage = sc.linkage;
        dsym.parent = sc.parent;
        //printf("this = %p, parent = %p, '%s'\n", this, parent, parent.toChars());
        dsym.protection = sc.protection;

        /* If scope's alignment is the default, use the type's alignment,
         * otherwise the scope overrrides.
         */
        dsym.alignment = sc.alignment();
        if (dsym.alignment == STRUCTALIGN_DEFAULT)
            dsym.alignment = dsym.type.alignment(); // use type's alignment

        //printf("sc.stc = %x\n", sc.stc);
        //printf("storage_class = x%x\n", storage_class);

        if (global.params.vcomplex)
            dsym.type.checkComplexTransition(dsym.loc);

        // Calculate type size + safety checks
        if (sc.func && !sc.intypeof)
        {
            if (dsym.storage_class & STCgshared && !dsym.isMember())
            {
                if (sc.func.setUnsafe())
                    dsym.error("__gshared not allowed in safe functions; use shared");
            }
        }

        Dsymbol parent = dsym.toParent();

        Type tb = dsym.type.toBasetype();
        Type tbn = tb.baseElemOf();
        if (tb.ty == Tvoid && !(dsym.storage_class & STClazy))
        {
            if (inferred)
            {
                dsym.error("type %s is inferred from initializer %s, and variables cannot be of type void", dsym.type.toChars(), dsym._init.toChars());
            }
            else
                dsym.error("variables cannot be of type void");
            dsym.type = Type.terror;
            tb = dsym.type;
        }
        if (tb.ty == Tfunction)
        {
            dsym.error("cannot be declared to be a function");
            dsym.type = Type.terror;
            tb = dsym.type;
        }
        if (tb.ty == Tstruct)
        {
            TypeStruct ts = cast(TypeStruct)tb;
            if (!ts.sym.members)
            {
                dsym.error("no definition of struct %s", ts.toChars());
            }
        }
        if ((dsym.storage_class & STCauto) && !inferred)
            dsym.error("storage class 'auto' has no effect if type is not inferred, did you mean 'scope'?");

        if (tb.ty == Ttuple)
        {
            /* Instead, declare variables for each of the tuple elements
             * and add those.
             */
            TypeTuple tt = cast(TypeTuple)tb;
            size_t nelems = Parameter.dim(tt.arguments);
            Expression ie = (dsym._init && !dsym._init.isVoidInitializer()) ? dsym._init.initializerToExpression() : null;
            if (ie)
                ie = ie.expressionSemantic(sc);
            if (nelems > 0 && ie)
            {
                auto iexps = new Expressions();
                iexps.push(ie);
                auto exps = new Expressions();
                for (size_t pos = 0; pos < iexps.dim; pos++)
                {
                Lexpand1:
                    Expression e = (*iexps)[pos];
                    Parameter arg = Parameter.getNth(tt.arguments, pos);
                    arg.type = arg.type.typeSemantic(dsym.loc, sc);
                    //printf("[%d] iexps.dim = %d, ", pos, iexps.dim);
                    //printf("e = (%s %s, %s), ", Token::tochars[e.op], e.toChars(), e.type.toChars());
                    //printf("arg = (%s, %s)\n", arg.toChars(), arg.type.toChars());

                    if (e != ie)
                    {
                        if (iexps.dim > nelems)
                            goto Lnomatch;
                        if (e.type.implicitConvTo(arg.type))
                            continue;
                    }

                    if (e.op == TOKtuple)
                    {
                        TupleExp te = cast(TupleExp)e;
                        if (iexps.dim - 1 + te.exps.dim > nelems)
                            goto Lnomatch;

                        iexps.remove(pos);
                        iexps.insert(pos, te.exps);
                        (*iexps)[pos] = Expression.combine(te.e0, (*iexps)[pos]);
                        goto Lexpand1;
                    }
                    else if (isAliasThisTuple(e))
                    {
                        auto v = copyToTemp(0, "__tup", e);
                        v.semantic(sc);
                        auto ve = new VarExp(dsym.loc, v);
                        ve.type = e.type;

                        exps.setDim(1);
                        (*exps)[0] = ve;
                        expandAliasThisTuples(exps, 0);

                        for (size_t u = 0; u < exps.dim; u++)
                        {
                        Lexpand2:
                            Expression ee = (*exps)[u];
                            arg = Parameter.getNth(tt.arguments, pos + u);
                            arg.type = arg.type.typeSemantic(dsym.loc, sc);
                            //printf("[%d+%d] exps.dim = %d, ", pos, u, exps.dim);
                            //printf("ee = (%s %s, %s), ", Token::tochars[ee.op], ee.toChars(), ee.type.toChars());
                            //printf("arg = (%s, %s)\n", arg.toChars(), arg.type.toChars());

                            size_t iexps_dim = iexps.dim - 1 + exps.dim;
                            if (iexps_dim > nelems)
                                goto Lnomatch;
                            if (ee.type.implicitConvTo(arg.type))
                                continue;

                            if (expandAliasThisTuples(exps, u) != -1)
                                goto Lexpand2;
                        }

                        if ((*exps)[0] != ve)
                        {
                            Expression e0 = (*exps)[0];
                            (*exps)[0] = new CommaExp(dsym.loc, new DeclarationExp(dsym.loc, v), e0);
                            (*exps)[0].type = e0.type;

                            iexps.remove(pos);
                            iexps.insert(pos, exps);
                            goto Lexpand1;
                        }
                    }
                }
                if (iexps.dim < nelems)
                    goto Lnomatch;

                ie = new TupleExp(dsym._init.loc, iexps);
            }
        Lnomatch:

            if (ie && ie.op == TOKtuple)
            {
                TupleExp te = cast(TupleExp)ie;
                size_t tedim = te.exps.dim;
                if (tedim != nelems)
                {
                    error(dsym.loc, "tuple of %d elements cannot be assigned to tuple of %d elements", cast(int)tedim, cast(int)nelems);
                    for (size_t u = tedim; u < nelems; u++) // fill dummy expression
                        te.exps.push(new ErrorExp());
                }
            }

            auto exps = new Objects();
            exps.setDim(nelems);
            for (size_t i = 0; i < nelems; i++)
            {
                Parameter arg = Parameter.getNth(tt.arguments, i);

                OutBuffer buf;
                buf.printf("__%s_field_%llu", dsym.ident.toChars(), cast(ulong)i);
                auto id = Identifier.idPool(buf.peekSlice());

                Initializer ti;
                if (ie)
                {
                    Expression einit = ie;
                    if (ie.op == TOKtuple)
                    {
                        TupleExp te = cast(TupleExp)ie;
                        einit = (*te.exps)[i];
                        if (i == 0)
                            einit = Expression.combine(te.e0, einit);
                    }
                    ti = new ExpInitializer(einit.loc, einit);
                }
                else
                    ti = dsym._init ? dsym._init.syntaxCopy() : null;

                StorageClass storage_class = STCtemp | dsym.storage_class;
                if (arg.storageClass & STCparameter)
                    storage_class |= arg.storageClass;
                auto v = new VarDeclaration(dsym.loc, arg.type, id, ti, storage_class);
                //printf("declaring field %s of type %s\n", v.toChars(), v.type.toChars());
                v.semantic(sc);

                if (sc.scopesym)
                {
                    //printf("adding %s to %s\n", v.toChars(), sc.scopesym.toChars());
                    if (sc.scopesym.members)
                        // Note this prevents using foreach() over members, because the limits can change
                        sc.scopesym.members.push(v);
                }

                Expression e = new DsymbolExp(dsym.loc, v);
                (*exps)[i] = e;
            }
            auto v2 = new TupleDeclaration(dsym.loc, dsym.ident, exps);
            v2.parent = dsym.parent;
            v2.isexp = true;
            dsym.aliassym = v2;
            dsym.semanticRun = PASSsemanticdone;
            return;
        }

        /* Storage class can modify the type
         */
        dsym.type = dsym.type.addStorageClass(dsym.storage_class);

        /* Adjust storage class to reflect type
         */
        if (dsym.type.isConst())
        {
            dsym.storage_class |= STCconst;
            if (dsym.type.isShared())
                dsym.storage_class |= STCshared;
        }
        else if (dsym.type.isImmutable())
            dsym.storage_class |= STCimmutable;
        else if (dsym.type.isShared())
            dsym.storage_class |= STCshared;
        else if (dsym.type.isWild())
            dsym.storage_class |= STCwild;

        if (StorageClass stc = dsym.storage_class & (STCsynchronized | STCoverride | STCabstract | STCfinal))
        {
            if (stc == STCfinal)
                dsym.error("cannot be final, perhaps you meant const?");
            else
            {
                OutBuffer buf;
                stcToBuffer(&buf, stc);
                dsym.error("cannot be %s", buf.peekString());
            }
            dsym.storage_class &= ~stc; // strip off
        }

        if (dsym.storage_class & STCscope)
        {
            StorageClass stc = dsym.storage_class & (STCstatic | STCextern | STCmanifest | STCtls | STCgshared);
            if (stc)
            {
                OutBuffer buf;
                stcToBuffer(&buf, stc);
                dsym.error("cannot be 'scope' and '%s'", buf.peekString());
            }
            else if (dsym.isMember())
            {
                dsym.error("field cannot be 'scope'");
            }
            else if (!dsym.type.hasPointers())
            {
                dsym.storage_class &= ~STCscope;     // silently ignore; may occur in generic code
            }
        }

        if (dsym.storage_class & (STCstatic | STCextern | STCmanifest | STCtemplateparameter | STCtls | STCgshared | STCctfe))
        {
        }
        else
        {
            AggregateDeclaration aad = parent.isAggregateDeclaration();
            if (aad)
            {
                if (global.params.vfield && dsym.storage_class & (STCconst | STCimmutable) && dsym._init && !dsym._init.isVoidInitializer())
                {
                    const(char)* p = dsym.loc.toChars();
                    const(char)* s = (dsym.storage_class & STCimmutable) ? "immutable" : "const";
                    fprintf(global.stdmsg, "%s: %s.%s is %s field\n", p ? p : "", ad.toPrettyChars(), dsym.toChars(), s);
                }
                dsym.storage_class |= STCfield;
                if (tbn.ty == Tstruct && (cast(TypeStruct)tbn).sym.noDefaultCtor)
                {
                    if (!dsym.isThisDeclaration() && !dsym._init)
                        aad.noDefaultCtor = true;
                }
            }

            InterfaceDeclaration id = parent.isInterfaceDeclaration();
            if (id)
            {
                dsym.error("field not allowed in interface");
            }
            else if (aad && aad.sizeok == SIZEOKdone)
            {
                dsym.error("cannot be further field because it will change the determined %s size", aad.toChars());
            }

            /* Templates cannot add fields to aggregates
             */
            TemplateInstance ti = parent.isTemplateInstance();
            if (ti)
            {
                // Take care of nested templates
                while (1)
                {
                    TemplateInstance ti2 = ti.tempdecl.parent.isTemplateInstance();
                    if (!ti2)
                        break;
                    ti = ti2;
                }
                // If it's a member template
                AggregateDeclaration ad2 = ti.tempdecl.isMember();
                if (ad2 && dsym.storage_class != STCundefined)
                {
                    dsym.error("cannot use template to add field to aggregate '%s'", ad2.toChars());
                }
            }
        }

        if ((dsym.storage_class & (STCref | STCparameter | STCforeach | STCtemp | STCresult)) == STCref && dsym.ident != Id.This)
        {
            dsym.error("only parameters or foreach declarations can be ref");
        }

        if (dsym.type.hasWild())
        {
            if (dsym.storage_class & (STCstatic | STCextern | STCtls | STCgshared | STCmanifest | STCfield) || dsym.isDataseg())
            {
                dsym.error("only parameters or stack based variables can be inout");
            }
            FuncDeclaration func = sc.func;
            if (func)
            {
                if (func.fes)
                    func = func.fes.func;
                bool isWild = false;
                for (FuncDeclaration fd = func; fd; fd = fd.toParent2().isFuncDeclaration())
                {
                    if ((cast(TypeFunction)fd.type).iswild)
                    {
                        isWild = true;
                        break;
                    }
                }
                if (!isWild)
                {
                    dsym.error("inout variables can only be declared inside inout functions");
                }
            }
        }

        if (!(dsym.storage_class & (STCctfe | STCref | STCresult)) && tbn.ty == Tstruct && (cast(TypeStruct)tbn).sym.noDefaultCtor)
        {
            if (!dsym._init)
            {
                if (dsym.isField())
                {
                    /* For fields, we'll check the constructor later to make sure it is initialized
                     */
                    dsym.storage_class |= STCnodefaultctor;
                }
                else if (dsym.storage_class & STCparameter)
                {
                }
                else
                    dsym.error("default construction is disabled for type %s", dsym.type.toChars());
            }
        }

        FuncDeclaration fd = parent.isFuncDeclaration();
        if (dsym.type.isscope() && !(dsym.storage_class & STCnodtor))
        {
            if (dsym.storage_class & (STCfield | STCout | STCref | STCstatic | STCmanifest | STCtls | STCgshared) || !fd)
            {
                dsym.error("globals, statics, fields, manifest constants, ref and out parameters cannot be scope");
            }
            if (!(dsym.storage_class & STCscope))
            {
                if (!(dsym.storage_class & STCparameter) && dsym.ident != Id.withSym)
                    dsym.error("reference to scope class must be scope");
            }
        }

        // Calculate type size + safety checks
        if (sc.func && !sc.intypeof)
        {
            if (dsym._init && dsym._init.isVoidInitializer() && dsym.type.hasPointers()) // get type size
            {
                if (sc.func.setUnsafe())
                    dsym.error("void initializers for pointers not allowed in safe functions");
            }
            else if (!dsym._init &&
                     !(dsym.storage_class & (STCstatic | STCextern | STCtls | STCgshared | STCmanifest | STCfield | STCparameter)) &&
                     dsym.type.hasVoidInitPointers())
            {
                if (sc.func.setUnsafe())
                    dsym.error("void initializers for pointers not allowed in safe functions");
            }
        }

        if (!dsym._init && !fd)
        {
            // If not mutable, initializable by constructor only
            dsym.storage_class |= STCctorinit;
        }

        if (dsym._init)
            dsym.storage_class |= STCinit; // remember we had an explicit initializer
        else if (dsym.storage_class & STCmanifest)
            dsym.error("manifest constants must have initializers");

        bool isBlit = false;
        d_uns64 sz;
        if (!dsym._init &&
            !sc.inunion &&
            !(dsym.storage_class & (STCstatic | STCgshared | STCextern)) &&
            fd &&
            (!(dsym.storage_class & (STCfield | STCin | STCforeach | STCparameter | STCresult)) ||
             (dsym.storage_class & STCout)) &&
            (sz = dsym.type.size()) != 0)
        {
            // Provide a default initializer

            //printf("Providing default initializer for '%s'\n", toChars());
            if (sz == SIZE_INVALID && dsym.type.ty != Terror)
                dsym.error("size of type %s is invalid", dsym.type.toChars());

            Type tv = dsym.type;
            while (tv.ty == Tsarray)    // Don't skip Tenum
                tv = tv.nextOf();
            if (tv.needsNested())
            {
                /* Nested struct requires valid enclosing frame pointer.
                 * In StructLiteralExp::toElem(), it's calculated.
                 */
                assert(tbn.ty == Tstruct);
                checkFrameAccess(dsym.loc, sc, (cast(TypeStruct)tbn).sym);

                Expression e = tv.defaultInitLiteral(dsym.loc);
                e = new BlitExp(dsym.loc, new VarExp(dsym.loc, dsym), e);
                e = e.expressionSemantic(sc);
                dsym._init = new ExpInitializer(dsym.loc, e);
                goto Ldtor;
            }
            if (tv.ty == Tstruct && (cast(TypeStruct)tv).sym.zeroInit == 1)
            {
                /* If a struct is all zeros, as a special case
                 * set it's initializer to the integer 0.
                 * In AssignExp::toElem(), we check for this and issue
                 * a memset() to initialize the struct.
                 * Must do same check in interpreter.
                 */
                Expression e = new IntegerExp(dsym.loc, 0, Type.tint32);
                e = new BlitExp(dsym.loc, new VarExp(dsym.loc, dsym), e);
                e.type = dsym.type;      // don't type check this, it would fail
                dsym._init = new ExpInitializer(dsym.loc, e);
                goto Ldtor;
            }
            if (dsym.type.baseElemOf().ty == Tvoid)
            {
                dsym.error("%s does not have a default initializer", dsym.type.toChars());
            }
            else if (auto e = dsym.type.defaultInit(dsym.loc))
            {
                dsym._init = new ExpInitializer(dsym.loc, e);
            }

            // Default initializer is always a blit
            isBlit = true;
        }
        if (dsym._init)
        {
            sc = sc.push();
            sc.stc &= ~(STC_TYPECTOR | STCpure | STCnothrow | STCnogc | STCref | STCdisable);

            ExpInitializer ei = dsym._init.isExpInitializer();
            if (ei) // https://issues.dlang.org/show_bug.cgi?id=13424
                    // Preset the required type to fail in FuncLiteralDeclaration::semantic3
                ei.exp = inferType(ei.exp, dsym.type);

            // If inside function, there is no semantic3() call
            if (sc.func || sc.intypeof == 1)
            {
                // If local variable, use AssignExp to handle all the various
                // possibilities.
                if (fd && !(dsym.storage_class & (STCmanifest | STCstatic | STCtls | STCgshared | STCextern)) && !dsym._init.isVoidInitializer())
                {
                    //printf("fd = '%s', var = '%s'\n", fd.toChars(), toChars());
                    if (!ei)
                    {
                        ArrayInitializer ai = dsym._init.isArrayInitializer();
                        Expression e;
                        if (ai && tb.ty == Taarray)
                            e = ai.toAssocArrayLiteral();
                        else
                            e = dsym._init.initializerToExpression();
                        if (!e)
                        {
                            // Run semantic, but don't need to interpret
                            dsym._init = dsym._init.semantic(sc, dsym.type, INITnointerpret);
                            e = dsym._init.initializerToExpression();
                            if (!e)
                            {
                                dsym.error("is not a static and cannot have static initializer");
                                e = new ErrorExp();
                            }
                        }
                        ei = new ExpInitializer(dsym._init.loc, e);
                        dsym._init = ei;
                    }

                    Expression exp = ei.exp;
                    Expression e1 = new VarExp(dsym.loc, dsym);
                    if (isBlit)
                        exp = new BlitExp(dsym.loc, e1, exp);
                    else
                        exp = new ConstructExp(dsym.loc, e1, exp);
                    dsym.canassign++;
                    exp = exp.expressionSemantic(sc);
                    dsym.canassign--;
                    exp = exp.optimize(WANTvalue);
                    if (exp.op == TOKerror)
                    {
                        dsym._init = new ErrorInitializer();
                        ei = null;
                    }
                    else
                        ei.exp = exp;

                    if (ei && dsym.isScope())
                    {
                        Expression ex = ei.exp;
                        while (ex.op == TOKcomma)
                            ex = (cast(CommaExp)ex).e2;
                        if (ex.op == TOKblit || ex.op == TOKconstruct)
                            ex = (cast(AssignExp)ex).e2;
                        if (ex.op == TOKnew)
                        {
                            // See if initializer is a NewExp that can be allocated on the stack
                            NewExp ne = cast(NewExp)ex;
                            if (dsym.type.toBasetype().ty == Tclass)
                            {
                                if (ne.newargs && ne.newargs.dim > 1)
                                {
                                    dsym.mynew = true;
                                }
                                else
                                {
                                    ne.onstack = 1;
                                    dsym.onstack = true;
                                }
                            }
                        }
                        else if (ex.op == TOKfunction)
                        {
                            // or a delegate that doesn't escape a reference to the function
                            FuncDeclaration f = (cast(FuncExp)ex).fd;
                            f.tookAddressOf--;
                        }
                    }
                }
                else
                {
                    // https://issues.dlang.org/show_bug.cgi?id=14166
                    // Don't run CTFE for the temporary variables inside typeof
                    dsym._init = dsym._init.semantic(sc, dsym.type, sc.intypeof == 1 ? INITnointerpret : INITinterpret);
                }
            }
            else if (parent.isAggregateDeclaration())
            {
                dsym._scope = scx ? scx : sc.copy();
                dsym._scope.setNoFree();
            }
            else if (dsym.storage_class & (STCconst | STCimmutable | STCmanifest) || dsym.type.isConst() || dsym.type.isImmutable())
            {
                /* Because we may need the results of a const declaration in a
                 * subsequent type, such as an array dimension, before semantic2()
                 * gets ordinarily run, try to run semantic2() now.
                 * Ignore failure.
                 */
                if (!inferred)
                {
                    uint errors = global.errors;
                    dsym.inuse++;
                    if (ei)
                    {
                        Expression exp = ei.exp.syntaxCopy();

                        bool needctfe = dsym.isDataseg() || (dsym.storage_class & STCmanifest);
                        if (needctfe)
                            sc = sc.startCTFE();
                        exp = exp.expressionSemantic(sc);
                        exp = resolveProperties(sc, exp);
                        if (needctfe)
                            sc = sc.endCTFE();

                        Type tb2 = dsym.type.toBasetype();
                        Type ti = exp.type.toBasetype();

                        /* The problem is the following code:
                         *  struct CopyTest {
                         *     double x;
                         *     this(double a) { x = a * 10.0;}
                         *     this(this) { x += 2.0; }
                         *  }
                         *  const CopyTest z = CopyTest(5.3);  // ok
                         *  const CopyTest w = z;              // not ok, postblit not run
                         *  static assert(w.x == 55.0);
                         * because the postblit doesn't get run on the initialization of w.
                         */
                        if (ti.ty == Tstruct)
                        {
                            StructDeclaration sd = (cast(TypeStruct)ti).sym;
                            /* Look to see if initializer involves a copy constructor
                             * (which implies a postblit)
                             */
                            // there is a copy constructor
                            // and exp is the same struct
                            if (sd.postblit && tb2.toDsymbol(null) == sd)
                            {
                                // The only allowable initializer is a (non-copy) constructor
                                if (exp.isLvalue())
                                    dsym.error("of type struct %s uses this(this), which is not allowed in static initialization", tb2.toChars());
                            }
                        }
                        ei.exp = exp;
                    }
                    dsym._init = dsym._init.semantic(sc, dsym.type, INITinterpret);
                    dsym.inuse--;
                    if (global.errors > errors)
                    {
                        dsym._init = new ErrorInitializer();
                        dsym.type = Type.terror;
                    }
                }
                else
                {
                    dsym._scope = scx ? scx : sc.copy();
                    dsym._scope.setNoFree();
                }
            }
            sc = sc.pop();
        }

    Ldtor:
        /* Build code to execute destruction, if necessary
         */
        dsym.edtor = dsym.callScopeDtor(sc);
        if (dsym.edtor)
        {
            if (sc.func && dsym.storage_class & (STCstatic | STCgshared))
                dsym.edtor = dsym.edtor.expressionSemantic(sc._module._scope);
            else
                dsym.edtor = dsym.edtor.expressionSemantic(sc);

            version (none)
            {
                // currently disabled because of std.stdio.stdin, stdout and stderr
                if (dsym.isDataseg() && !(dsym.storage_class & STCextern))
                    dsym.error("static storage variables cannot have destructors");
            }
        }

        dsym.semanticRun = PASSsemanticdone;

        if (dsym.type.toBasetype().ty == Terror)
            dsym.errors = true;

        if(sc.scopesym && !sc.scopesym.isAggregateDeclaration())
        {
            for (ScopeDsymbol sym = sc.scopesym; sym && dsym.endlinnum == 0;
                 sym = sym.parent ? sym.parent.isScopeDsymbol() : null)
                dsym.endlinnum = sym.endlinnum;
        }
    }

    override void visit(TypeInfoDeclaration dsym)
    {
        assert(dsym.linkage == LINKc);
    }

    override void visit(Import imp)
    {
        //printf("Import::semantic('%s') %s\n", toPrettyChars(), id.toChars());
        if (imp.semanticRun > PASSinit)
            return;

        if (imp._scope)
        {
            sc = imp._scope;
            imp._scope = null;
        }
        if (!sc)
            return;

        imp.semanticRun = PASSsemantic;

        // Load if not already done so
        if (!imp.mod)
        {
            imp.load(sc);
            if (imp.mod)
                imp.mod.importAll(null);
        }
        if (imp.mod)
        {
            // Modules need a list of each imported module
            //printf("%s imports %s\n", sc.module.toChars(), mod.toChars());
            sc._module.aimports.push(imp.mod);

            if (sc.explicitProtection)
                imp.protection = sc.protection;

            if (!imp.aliasId && !imp.names.dim) // neither a selective nor a renamed import
            {
                ScopeDsymbol scopesym;
                for (Scope* scd = sc; scd; scd = scd.enclosing)
                {
                    if (!scd.scopesym)
                        continue;
                    scopesym = scd.scopesym;
                    break;
                }

                if (!imp.isstatic)
                {
                    scopesym.importScope(imp.mod, imp.protection);
                }

                // Mark the imported packages as accessible from the current
                // scope. This access check is necessary when using FQN b/c
                // we're using a single global package tree.
                // https://issues.dlang.org/show_bug.cgi?id=313
                if (imp.packages)
                {
                    // import a.b.c.d;
                    auto p = imp.pkg; // a
                    scopesym.addAccessiblePackage(p, imp.protection);
                    foreach (id; (*imp.packages)[1 .. imp.packages.dim]) // [b, c]
                    {
                        p = cast(Package) p.symtab.lookup(id);
                        scopesym.addAccessiblePackage(p, imp.protection);
                    }
                }
                scopesym.addAccessiblePackage(imp.mod, imp.protection); // d
            }

            imp.mod.semantic(null);
            if (imp.mod.needmoduleinfo)
            {
                //printf("module4 %s because of %s\n", sc.module.toChars(), mod.toChars());
                sc._module.needmoduleinfo = 1;
            }

            sc = sc.push(imp.mod);
            sc.protection = imp.protection;
            for (size_t i = 0; i < imp.aliasdecls.dim; i++)
            {
                AliasDeclaration ad = imp.aliasdecls[i];
                //printf("\tImport %s alias %s = %s, scope = %p\n", toPrettyChars(), aliases[i].toChars(), names[i].toChars(), ad._scope);
                if (imp.mod.search(imp.loc, imp.names[i]))
                {
                    ad.semantic(sc);
                    // If the import declaration is in non-root module,
                    // analysis of the aliased symbol is deferred.
                    // Therefore, don't see the ad.aliassym or ad.type here.
                }
                else
                {
                    Dsymbol s = imp.mod.search_correct(imp.names[i]);
                    if (s)
                        imp.mod.error(imp.loc, "import '%s' not found, did you mean %s '%s'?", imp.names[i].toChars(), s.kind(), s.toChars());
                    else
                        imp.mod.error(imp.loc, "import '%s' not found", imp.names[i].toChars());
                    ad.type = Type.terror;
                }
            }
            sc = sc.pop();
        }

        imp.semanticRun = PASSsemanticdone;

        // object self-imports itself, so skip that
        // https://issues.dlang.org/show_bug.cgi?id=7547
        // don't list pseudo modules __entrypoint.d, __main.d
        // https://issues.dlang.org/show_bug.cgi?id=11117
        // https://issues.dlang.org/show_bug.cgi?id=11164
        if (global.params.moduleDeps !is null && !(imp.id == Id.object && sc._module.ident == Id.object) &&
            sc._module.ident != Id.entrypoint &&
            strcmp(sc._module.ident.toChars(), "__main") != 0)
        {
            /* The grammar of the file is:
             *      ImportDeclaration
             *          ::= BasicImportDeclaration [ " : " ImportBindList ] [ " -> "
             *      ModuleAliasIdentifier ] "\n"
             *
             *      BasicImportDeclaration
             *          ::= ModuleFullyQualifiedName " (" FilePath ") : " Protection|"string"
             *              " [ " static" ] : " ModuleFullyQualifiedName " (" FilePath ")"
             *
             *      FilePath
             *          - any string with '(', ')' and '\' escaped with the '\' character
             */
            OutBuffer* ob = global.params.moduleDeps;
            Module imod = sc.instantiatingModule();
            if (!global.params.moduleDepsFile)
                ob.writestring("depsImport ");
            ob.writestring(imod.toPrettyChars());
            ob.writestring(" (");
            escapePath(ob, imod.srcfile.toChars());
            ob.writestring(") : ");
            // use protection instead of sc.protection because it couldn't be
            // resolved yet, see the comment above
            protectionToBuffer(ob, imp.protection);
            ob.writeByte(' ');
            if (imp.isstatic)
            {
                stcToBuffer(ob, STCstatic);
                ob.writeByte(' ');
            }
            ob.writestring(": ");
            if (imp.packages)
            {
                for (size_t i = 0; i < imp.packages.dim; i++)
                {
                    Identifier pid = (*imp.packages)[i];
                    ob.printf("%s.", pid.toChars());
                }
            }
            ob.writestring(imp.id.toChars());
            ob.writestring(" (");
            if (imp.mod)
                escapePath(ob, imp.mod.srcfile.toChars());
            else
                ob.writestring("???");
            ob.writeByte(')');
            for (size_t i = 0; i < imp.names.dim; i++)
            {
                if (i == 0)
                    ob.writeByte(':');
                else
                    ob.writeByte(',');
                Identifier name = imp.names[i];
                Identifier _alias = imp.aliases[i];
                if (!_alias)
                {
                    ob.printf("%s", name.toChars());
                    _alias = name;
                }
                else
                    ob.printf("%s=%s", _alias.toChars(), name.toChars());
            }
            if (imp.aliasId)
                ob.printf(" -> %s", imp.aliasId.toChars());
            ob.writenl();
        }
        //printf("-Import::semantic('%s'), pkg = %p\n", toChars(), pkg);
    }

    void attribSemantic(AttribDeclaration ad)
    {
        if (ad.semanticRun != PASSinit)
            return;
        ad.semanticRun = PASSsemantic;
        Dsymbols* d = ad.include(sc, null);
        //printf("\tAttribDeclaration::semantic '%s', d = %p\n",toChars(), d);
        if (d)
        {
            Scope* sc2 = ad.newScope(sc);
            bool errors;
            for (size_t i = 0; i < d.dim; i++)
            {
                Dsymbol s = (*d)[i];
                s.semantic(sc2);
                errors |= s.errors;
            }
            ad.errors |= errors;
            if (sc2 != sc)
                sc2.pop();
        }
        ad.semanticRun = PASSsemanticdone;
    }

    override void visit(AttribDeclaration atd)
    {
        attribSemantic(atd);
    }

    override void visit(AnonDeclaration scd)
    {
        //printf("\tAnonDeclaration::semantic %s %p\n", isunion ? "union" : "struct", this);
        assert(sc.parent);
        auto p = sc.parent.pastMixin();
        auto ad = p.isAggregateDeclaration();
        if (!ad)
        {
            error(scd.loc, "%s can only be a part of an aggregate, not %s `%s`", scd.kind(), p.kind(), p.toChars());
            scd.errors = true;
            return;
        }

        if (scd.decl)
        {
            sc = sc.push();
            sc.stc &= ~(STCauto | STCscope | STCstatic | STCtls | STCgshared);
            sc.inunion = scd.isunion;
            sc.flags = 0;
            for (size_t i = 0; i < scd.decl.dim; i++)
            {
                Dsymbol s = (*scd.decl)[i];
                s.semantic(sc);
            }
            sc = sc.pop();
        }
    }

    override void visit(PragmaDeclaration pd)
    {
        // Should be merged with PragmaStatement
        //printf("\tPragmaDeclaration::semantic '%s'\n",toChars());

        version(IN_LLVM)
        {
            LDCPragma llvm_internal = LDCPragma.LLVMnone;
            const(char)* arg1str = null;
        }

        if (pd.ident == Id.msg)
        {
            if (pd.args)
            {
                for (size_t i = 0; i < pd.args.dim; i++)
                {
                    Expression e = (*pd.args)[i];
                    sc = sc.startCTFE();
                    e = e.expressionSemantic(sc);
                    e = resolveProperties(sc, e);
                    sc = sc.endCTFE();
                    // pragma(msg) is allowed to contain types as well as expressions
                    e = ctfeInterpretForPragmaMsg(e);
                    if (e.op == TOKerror)
                    {
                        errorSupplemental(pd.loc, "while evaluating pragma(msg, %s)", (*pd.args)[i].toChars());
                        return;
                    }
                    StringExp se = e.toStringExp();
                    if (se)
                    {
                        se = se.toUTF8(sc);
                        fprintf(stderr, "%.*s", cast(int)se.len, se.string);
                    }
                    else
                        fprintf(stderr, "%s", e.toChars());
                }
                fprintf(stderr, "\n");
            }
            goto Lnodecl;
        }
        else if (pd.ident == Id.lib)
        {
            if (!pd.args || pd.args.dim != 1)
                pd.error("string expected for library name");
            else
            {
                auto se = semanticString(sc, (*pd.args)[0], "library name");
                if (!se)
                    goto Lnodecl;
                (*pd.args)[0] = se;

                auto name = cast(char*)mem.xmalloc(se.len + 1);
                memcpy(name, se.string, se.len);
                name[se.len] = 0;
                if (global.params.verbose)
                    fprintf(global.stdmsg, "library   %s\n", name);
                if (global.params.moduleDeps && !global.params.moduleDepsFile)
                {
                    OutBuffer* ob = global.params.moduleDeps;
                    Module imod = sc.instantiatingModule();
                    ob.writestring("depsLib ");
                    ob.writestring(imod.toPrettyChars());
                    ob.writestring(" (");
                    escapePath(ob, imod.srcfile.toChars());
                    ob.writestring(") : ");
                    ob.writestring(name);
                    ob.writenl();
                }
                mem.xfree(name);
            }
            goto Lnodecl;
        }
        else if (pd.ident == Id.startaddress)
        {
            if (!pd.args || pd.args.dim != 1)
                pd.error("function name expected for start address");
            else
            {
                /* https://issues.dlang.org/show_bug.cgi?id=11980
                 * resolveProperties and ctfeInterpret call are not necessary.
                 */
                Expression e = (*pd.args)[0];
                sc = sc.startCTFE();
                e = e.expressionSemantic(sc);
                sc = sc.endCTFE();
                (*pd.args)[0] = e;
                Dsymbol sa = getDsymbol(e);
                if (!sa || !sa.isFuncDeclaration())
                    pd.error("function name expected for start address, not `%s`", e.toChars());
            }
            goto Lnodecl;
        }
        else if (pd.ident == Id.Pinline)
        {
            goto Ldecl;
        }
        else if (pd.ident == Id.mangle)
        {
            if (!pd.args)
                pd.args = new Expressions();
            if (pd.args.dim != 1)
            {
                pd.error("string expected for mangled name");
                pd.args.setDim(1);
                (*pd.args)[0] = new ErrorExp(); // error recovery
                goto Ldecl;
            }

            auto se = semanticString(sc, (*pd.args)[0], "mangled name");
            if (!se)
                goto Ldecl;
            (*pd.args)[0] = se; // Will be used later

            if (!se.len)
            {
                pd.error("zero-length string not allowed for mangled name");
                goto Ldecl;
            }
            if (se.sz != 1)
            {
                pd.error("mangled name characters can only be of type char");
                goto Ldecl;
            }
            version (all)
            {
                /* Note: D language specification should not have any assumption about backend
                 * implementation. Ideally pragma(mangle) can accept a string of any content.
                 *
                 * Therefore, this validation is compiler implementation specific.
                 */
                for (size_t i = 0; i < se.len;)
                {
                    char* p = se.string;
                    dchar c = p[i];
                    if (c < 0x80)
                    {
                        if (c >= 'A' && c <= 'Z' || c >= 'a' && c <= 'z' || c >= '0' && c <= '9' || c != 0 && strchr("$%().:?@[]_", c))
                        {
                            ++i;
                            continue;
                        }
                        else
                        {
                            pd.error("char 0x%02x not allowed in mangled name", c);
                            break;
                        }
                    }
                    if (const msg = utf_decodeChar(se.string, se.len, i, c))
                    {
                        pd.error("%s", msg);
                        break;
                    }
                    if (!isUniAlpha(c))
                    {
                        pd.error("char `0x%04x` not allowed in mangled name", c);
                        break;
                    }
                }
            }
        }
        // IN_LLVM
        else if ((llvm_internal = DtoGetPragma(sc, pd, arg1str)) != LDCPragma.LLVMnone)
        {
            // nothing to do anymore
        }
        else if (global.params.ignoreUnsupportedPragmas)
        {
            if (global.params.verbose)
            {
                /* Print unrecognized pragmas
                 */
                fprintf(global.stdmsg, "pragma    %s", pd.ident.toChars());
                if (pd.args)
                {
                    for (size_t i = 0; i < pd.args.dim; i++)
                    {
                        Expression e = (*pd.args)[i];
                        version(IN_LLVM)
                        {
                            // ignore errors in ignored pragmas.
                            global.gag++;
                            uint errors_save = global.errors;
                        }
                        sc = sc.startCTFE();
                        e = e.expressionSemantic(sc);
                        e = resolveProperties(sc, e);
                        sc = sc.endCTFE();
                        e = e.ctfeInterpret();
                        if (i == 0)
                            fprintf(global.stdmsg, " (");
                        else
                            fprintf(global.stdmsg, ",");
                        fprintf(global.stdmsg, "%s", e.toChars());
                        version(IN_LLVM)
                        {
                            // restore error state.
                            global.gag--;
                            global.errors = errors_save;
                        }
                    }
                    if (pd.args.dim)
                        fprintf(global.stdmsg, ")");
                }
                fprintf(global.stdmsg, "\n");
            }
            static if (!IN_LLVM)
                goto Lnodecl;
        }
        else
            pd.error("unrecognized `pragma(%s)`", pd.ident.toChars());
    Ldecl:
        if (pd.decl)
        {
            Scope* sc2 = pd.newScope(sc);
            for (size_t i = 0; i < pd.decl.dim; i++)
            {
                Dsymbol s = (*pd.decl)[i];
                s.semantic(sc2);
                if (pd.ident == Id.mangle)
                {
                    assert(pd.args && pd.args.dim == 1);
                    if (auto se = (*pd.args)[0].toStringExp())
                    {
                        char* name = cast(char*)mem.xmalloc(se.len + 1);
                        memcpy(name, se.string, se.len);
                        name[se.len] = 0;
                        uint cnt = setMangleOverride(s, name);
                        if (cnt > 1)
                            pd.error("can only apply to a single declaration");
                    }
                }
                // IN_LLVM: add else clause
                else
                {
                    DtoCheckPragma(pd, s, llvm_internal, arg1str);
                }
            }
            if (sc2 != sc)
                sc2.pop();
        }
        return;
    Lnodecl:
        if (pd.decl)
        {
            pd.error("pragma is missing closing `;`");
            goto Ldecl;
            // do them anyway, to avoid segfaults.
        }
    }

    override void visit(StaticIfDeclaration sid)
    {
        attribSemantic(sid);
    }

    override void visit(StaticForeachDeclaration sfd)
    {
        attribSemantic(sfd);
    }

    void compileIt(CompileDeclaration cd, Scope* sc)
    {
        //printf("CompileDeclaration::compileIt(loc = %d) %s\n", loc.linnum, exp.toChars());
        auto se = semanticString(sc, cd.exp, "argument to mixin");
        if (!se)
            return;
        se = se.toUTF8(sc);

        uint errors = global.errors;
        scope p = new Parser!ASTCodegen(cd.loc, sc._module, se.toStringz(), false);
        p.nextToken();

        cd.decl = p.parseDeclDefs(0);
        if (p.token.value != TOKeof)
            cd.exp.error("incomplete mixin declaration `%s`", se.toChars());
        if (p.errors)
        {
            assert(global.errors != errors);
            cd.decl = null;
        }
    }

    override void visit(CompileDeclaration cd)
    {
        //printf("CompileDeclaration::semantic()\n");
        if (!cd.compiled)
        {
            compileIt(cd, sc);
            cd.AttribDeclaration.addMember(sc, cd.scopesym);
            cd.compiled = true;

            if (cd._scope && cd.decl)
            {
                for (size_t i = 0; i < cd.decl.dim; i++)
                {
                    Dsymbol s = (*cd.decl)[i];
                    s.setScope(cd._scope);
                }
            }
        }
        attribSemantic(cd);
    }

    override void visit(UserAttributeDeclaration uad)
    {
        //printf("UserAttributeDeclaration::semantic() %p\n", this);
        if (uad.decl && !uad._scope)
            uad.Dsymbol.setScope(sc); // for function local symbols
        return attribSemantic(uad);
    }

    override void visit(StaticAssert sa)
    {
        if (sa.semanticRun < PASSsemanticdone)
            sa.semanticRun = PASSsemanticdone;
    }

    override void visit(DebugSymbol ds)
    {
        //printf("DebugSymbol::semantic() %s\n", toChars());
        if (ds.semanticRun < PASSsemanticdone)
            ds.semanticRun = PASSsemanticdone;
    }

    override void visit(VersionSymbol vs)
    {
        if (vs.semanticRun < PASSsemanticdone)
            vs.semanticRun = PASSsemanticdone;
    }

    override void visit(Package pkg)
    {
        if (pkg.semanticRun < PASSsemanticdone)
            pkg.semanticRun = PASSsemanticdone;
    }

    override void visit(Module m)
    {
        if (m.semanticRun != PASSinit)
            return;
        //printf("+Module::semantic(this = %p, '%s'): parent = %p\n", this, toChars(), parent);
        m.semanticRun = PASSsemantic;
        // Note that modules get their own scope, from scratch.
        // This is so regardless of where in the syntax a module
        // gets imported, it is unaffected by context.
        Scope* sc = m._scope; // see if already got one from importAll()
        if (!sc)
        {
            Scope.createGlobal(m); // create root scope
        }
        //printf("Module = %p, linkage = %d\n", sc.scopesym, sc.linkage);
        // Pass 1 semantic routines: do public side of the definition
        for (size_t i = 0; i < m.members.dim; i++)
        {
            Dsymbol s = (*m.members)[i];
            //printf("\tModule('%s'): '%s'.semantic()\n", toChars(), s.toChars());
            s.semantic(sc);
            m.runDeferredSemantic();
        }
        if (m.userAttribDecl)
        {
            m.userAttribDecl.semantic(sc);
        }
        if (!m._scope)
        {
            sc = sc.pop();
            sc.pop(); // 2 pops because Scope::createGlobal() created 2
        }
        m.semanticRun = PASSsemanticdone;
        //printf("-Module::semantic(this = %p, '%s'): parent = %p\n", this, toChars(), parent);
    }

    override void visit(EnumDeclaration ed)
    {
        //printf("EnumDeclaration::semantic(sd = %p, '%s') %s\n", sc.scopesym, sc.scopesym.toChars(), toChars());
        //printf("EnumDeclaration::semantic() %p %s\n", this, toChars());
        if (ed.semanticRun >= PASSsemanticdone)
            return; // semantic() already completed
        if (ed.semanticRun == PASSsemantic)
        {
            assert(ed.memtype);
            error(ed.loc, "circular reference to enum base type `%s`", ed.memtype.toChars());
            ed.errors = true;
            ed.semanticRun = PASSsemanticdone;
            return;
        }
        uint dprogress_save = Module.dprogress;

        Scope* scx = null;
        if (ed._scope)
        {
            sc = ed._scope;
            scx = ed._scope; // save so we don't make redundant copies
            ed._scope = null;
        }

        if (!sc)
            return;

        ed.parent = sc.parent;
        ed.type = ed.type.typeSemantic(ed.loc, sc);

        ed.protection = sc.protection;
        if (sc.stc & STCdeprecated)
            ed.isdeprecated = true;
        ed.userAttribDecl = sc.userAttribDecl;

        ed.semanticRun = PASSsemantic;

        if (!ed.members && !ed.memtype) // enum ident;
        {
            ed.semanticRun = PASSsemanticdone;
            return;
        }

        if (!ed.symtab)
            ed.symtab = new DsymbolTable();

        /* The separate, and distinct, cases are:
         *  1. enum { ... }
         *  2. enum : memtype { ... }
         *  3. enum ident { ... }
         *  4. enum ident : memtype { ... }
         *  5. enum ident : memtype;
         *  6. enum ident;
         */

        if (ed.memtype)
        {
            ed.memtype = ed.memtype.typeSemantic(ed.loc, sc);

            /* Check to see if memtype is forward referenced
             */
            if (ed.memtype.ty == Tenum)
            {
                EnumDeclaration sym = cast(EnumDeclaration)ed.memtype.toDsymbol(sc);
                if (!sym.memtype || !sym.members || !sym.symtab || sym._scope)
                {
                    // memtype is forward referenced, so try again later
                    ed._scope = scx ? scx : sc.copy();
                    ed._scope.setNoFree();
                    ed._scope._module.addDeferredSemantic(ed);
                    Module.dprogress = dprogress_save;
                    //printf("\tdeferring %s\n", toChars());
                    ed.semanticRun = PASSinit;
                    return;
                }
            }
            if (ed.memtype.ty == Tvoid)
            {
                ed.error("base type must not be void");
                ed.memtype = Type.terror;
            }
            if (ed.memtype.ty == Terror)
            {
                ed.errors = true;
                if (ed.members)
                {
                    for (size_t i = 0; i < ed.members.dim; i++)
                    {
                        Dsymbol s = (*ed.members)[i];
                        s.errors = true; // poison all the members
                    }
                }
                ed.semanticRun = PASSsemanticdone;
                return;
            }
        }

        ed.semanticRun = PASSsemanticdone;

        if (!ed.members) // enum ident : memtype;
            return;

        if (ed.members.dim == 0)
        {
            ed.error("enum `%s` must have at least one member", ed.toChars());
            ed.errors = true;
            return;
        }

        Module.dprogress++;

        Scope* sce;
        if (ed.isAnonymous())
            sce = sc;
        else
        {
            sce = sc.push(ed);
            sce.parent = ed;
        }
        sce = sce.startCTFE();
        sce.setNoFree(); // needed for getMaxMinValue()

        /* Each enum member gets the sce scope
         */
        for (size_t i = 0; i < ed.members.dim; i++)
        {
            EnumMember em = (*ed.members)[i].isEnumMember();
            if (em)
                em._scope = sce;
        }

        if (!ed.added)
        {
            /* addMember() is not called when the EnumDeclaration appears as a function statement,
             * so we have to do what addMember() does and install the enum members in the right symbol
             * table
             */
            ScopeDsymbol scopesym = null;
            if (ed.isAnonymous())
            {
                /* Anonymous enum members get added to enclosing scope.
                 */
                for (Scope* sct = sce; 1; sct = sct.enclosing)
                {
                    assert(sct);
                    if (sct.scopesym)
                    {
                        scopesym = sct.scopesym;
                        if (!sct.scopesym.symtab)
                            sct.scopesym.symtab = new DsymbolTable();
                        break;
                    }
                }
            }
            else
            {
                // Otherwise enum members are in the EnumDeclaration's symbol table
                scopesym = ed;
            }

            for (size_t i = 0; i < ed.members.dim; i++)
            {
                EnumMember em = (*ed.members)[i].isEnumMember();
                if (em)
                {
                    em.ed = ed;
                    em.addMember(sc, scopesym);
                }
            }
        }

        for (size_t i = 0; i < ed.members.dim; i++)
        {
            EnumMember em = (*ed.members)[i].isEnumMember();
            if (em)
                em.semantic(em._scope);
        }
        //printf("defaultval = %lld\n", defaultval);

        //if (defaultval) printf("defaultval: %s %s\n", defaultval.toChars(), defaultval.type.toChars());
        //printf("members = %s\n", members.toChars());
    }

    override void visit(EnumMember em)
    {
        //printf("EnumMember::semantic() %s\n", toChars());

        void errorReturn()
        {
            em.errors = true;
            em.semanticRun = PASSsemanticdone;
        }

        if (em.errors || em.semanticRun >= PASSsemanticdone)
            return;
        if (em.semanticRun == PASSsemantic)
        {
            em.error("circular reference to enum member");
            return errorReturn();
        }
        assert(em.ed);
        em.ed.semantic(sc);
        if (em.ed.errors)
            return errorReturn();
        if (em.errors || em.semanticRun >= PASSsemanticdone)
            return;

        if (em._scope)
            sc = em._scope;
        if (!sc)
            return;

        em.semanticRun = PASSsemantic;

        em.protection = em.ed.isAnonymous() ? em.ed.protection : Prot(PROTpublic);
        em.linkage = LINKd;
        em.storage_class = STCmanifest;
        em.userAttribDecl = em.ed.isAnonymous() ? em.ed.userAttribDecl : null;

        // The first enum member is special
        bool first = (em == (*em.ed.members)[0]);

        if (em.origType)
        {
            em.origType = em.origType.typeSemantic(em.loc, sc);
            em.type = em.origType;
            assert(em.value); // "type id;" is not a valid enum member declaration
        }

        if (em.value)
        {
            Expression e = em.value;
            assert(e.dyncast() == DYNCAST.expression);
            e = e.expressionSemantic(sc);
            e = resolveProperties(sc, e);
            e = e.ctfeInterpret();
            if (e.op == TOKerror)
                return errorReturn();
            if (first && !em.ed.memtype && !em.ed.isAnonymous())
            {
                em.ed.memtype = e.type;
                if (em.ed.memtype.ty == Terror)
                {
                    em.ed.errors = true;
                    return errorReturn();
                }
                if (em.ed.memtype.ty != Terror)
                {
                    /* https://issues.dlang.org/show_bug.cgi?id=11746
                     * All of named enum members should have same type
                     * with the first member. If the following members were referenced
                     * during the first member semantic, their types should be unified.
                     */
                    for (size_t i = 0; i < em.ed.members.dim; i++)
                    {
                        EnumMember enm = (*em.ed.members)[i].isEnumMember();
                        if (!enm || enm == em || enm.semanticRun < PASSsemanticdone || enm.origType)
                            continue;

                        //printf("[%d] em = %s, em.semanticRun = %d\n", i, toChars(), em.semanticRun);
                        Expression ev = enm.value;
                        ev = ev.implicitCastTo(sc, em.ed.memtype);
                        ev = ev.ctfeInterpret();
                        ev = ev.castTo(sc, em.ed.type);
                        if (ev.op == TOKerror)
                            em.ed.errors = true;
                        enm.value = ev;
                    }
                    if (em.ed.errors)
                    {
                        em.ed.memtype = Type.terror;
                        return errorReturn();
                    }
                }
            }

            if (em.ed.memtype && !em.origType)
            {
                e = e.implicitCastTo(sc, em.ed.memtype);
                e = e.ctfeInterpret();

                // save origValue for better json output
                em.origValue = e;

                if (!em.ed.isAnonymous())
                {
                    e = e.castTo(sc, em.ed.type);
                    e = e.ctfeInterpret();
                }
            }
            else if (em.origType)
            {
                e = e.implicitCastTo(sc, em.origType);
                e = e.ctfeInterpret();
                assert(em.ed.isAnonymous());

                // save origValue for better json output
                em.origValue = e;
            }
            em.value = e;
        }
        else if (first)
        {
            Type t;
            if (em.ed.memtype)
                t = em.ed.memtype;
            else
            {
                t = Type.tint32;
                if (!em.ed.isAnonymous())
                    em.ed.memtype = t;
            }
            Expression e = new IntegerExp(em.loc, 0, Type.tint32);
            e = e.implicitCastTo(sc, t);
            e = e.ctfeInterpret();

            // save origValue for better json output
            em.origValue = e;

            if (!em.ed.isAnonymous())
            {
                e = e.castTo(sc, em.ed.type);
                e = e.ctfeInterpret();
            }
            em.value = e;
        }
        else
        {
            /* Find the previous enum member,
             * and set this to be the previous value + 1
             */
            EnumMember emprev = null;
            for (size_t i = 0; i < em.ed.members.dim; i++)
            {
                EnumMember enm = (*em.ed.members)[i].isEnumMember();
                if (enm)
                {
                    if (enm == em)
                        break;
                    emprev = enm;
                }
            }
            assert(emprev);
            if (emprev.semanticRun < PASSsemanticdone) // if forward reference
                emprev.semantic(emprev._scope); // resolve it
            if (emprev.errors)
                return errorReturn();

            Expression eprev = emprev.value;
            Type tprev = eprev.type.equals(em.ed.type) ? em.ed.memtype : eprev.type;

            Expression emax = tprev.getProperty(em.ed.loc, Id.max, 0);
            emax = emax.expressionSemantic(sc);
            emax = emax.ctfeInterpret();

            // Set value to (eprev + 1).
            // But first check that (eprev != emax)
            assert(eprev);
            Expression e = new EqualExp(TOKequal, em.loc, eprev, emax);
            e = e.expressionSemantic(sc);
            e = e.ctfeInterpret();
            if (e.toInteger())
            {
                em.error("initialization with `%s.%s+1` causes overflow for type `%s`",
                    emprev.ed.toChars(), emprev.toChars(), em.ed.memtype.toChars());
                return errorReturn();
            }

            // Now set e to (eprev + 1)
            e = new AddExp(em.loc, eprev, new IntegerExp(em.loc, 1, Type.tint32));
            e = e.expressionSemantic(sc);
            e = e.castTo(sc, eprev.type);
            e = e.ctfeInterpret();

            // save origValue (without cast) for better json output
            if (e.op != TOKerror) // avoid duplicate diagnostics
            {
                assert(emprev.origValue);
                em.origValue = new AddExp(em.loc, emprev.origValue, new IntegerExp(em.loc, 1, Type.tint32));
                em.origValue = em.origValue.expressionSemantic(sc);
                em.origValue = em.origValue.ctfeInterpret();
            }

            if (e.op == TOKerror)
                return errorReturn();
            if (e.type.isfloating())
            {
                // Check that e != eprev (not always true for floats)
                Expression etest = new EqualExp(TOKequal, em.loc, e, eprev);
                etest = etest.expressionSemantic(sc);
                etest = etest.ctfeInterpret();
                if (etest.toInteger())
                {
                    em.error("has inexact value due to loss of precision");
                    return errorReturn();
                }
            }
            em.value = e;
        }
        if (!em.origType)
            em.type = em.value.type;

        assert(em.origValue);
        em.semanticRun = PASSsemanticdone;
    }

    override void visit(TemplateDeclaration tempdecl)
    {
        static if (LOG)
        {
            printf("TemplateDeclaration.semantic(this = %p, id = '%s')\n", this, tempdecl.ident.toChars());
            printf("sc.stc = %llx\n", sc.stc);
            printf("sc.module = %s\n", sc._module.toChars());
        }
        if (tempdecl.semanticRun != PASSinit)
            return; // semantic() already run

        // Remember templates defined in module object that we need to know about
        if (sc._module && sc._module.ident == Id.object)
        {
            if (tempdecl.ident == Id.RTInfo)
                Type.rtinfo = tempdecl;
        }

        /* Remember Scope for later instantiations, but make
         * a copy since attributes can change.
         */
        if (!tempdecl._scope)
        {
            tempdecl._scope = sc.copy();
            tempdecl._scope.setNoFree();
        }

        tempdecl.semanticRun = PASSsemantic;

        tempdecl.parent = sc.parent;
        tempdecl.protection = sc.protection;
        tempdecl.isstatic = tempdecl.toParent().isModule() || (tempdecl._scope.stc & STCstatic);

        if (!tempdecl.isstatic)
        {
            if (auto ad = tempdecl.parent.pastMixin().isAggregateDeclaration())
                ad.makeNested();
        }

        // Set up scope for parameters
        auto paramsym = new ScopeDsymbol();
        paramsym.parent = tempdecl.parent;
        Scope* paramscope = sc.push(paramsym);
        paramscope.stc = 0;

        if (global.params.doDocComments)
        {
            tempdecl.origParameters = new TemplateParameters();
            tempdecl.origParameters.setDim(tempdecl.parameters.dim);
            for (size_t i = 0; i < tempdecl.parameters.dim; i++)
            {
                TemplateParameter tp = (*tempdecl.parameters)[i];
                (*tempdecl.origParameters)[i] = tp.syntaxCopy();
            }
        }

        for (size_t i = 0; i < tempdecl.parameters.dim; i++)
        {
            TemplateParameter tp = (*tempdecl.parameters)[i];
            if (!tp.declareParameter(paramscope))
            {
                error(tp.loc, "parameter '%s' multiply defined", tp.ident.toChars());
                tempdecl.errors = true;
            }
            if (!tp.tpsemantic(paramscope, tempdecl.parameters))
            {
                tempdecl.errors = true;
            }
            if (i + 1 != tempdecl.parameters.dim && tp.isTemplateTupleParameter())
            {
                tempdecl.error("template tuple parameter must be last one");
                tempdecl.errors = true;
            }
        }

        /* Calculate TemplateParameter.dependent
         */
        TemplateParameters tparams;
        tparams.setDim(1);
        for (size_t i = 0; i < tempdecl.parameters.dim; i++)
        {
            TemplateParameter tp = (*tempdecl.parameters)[i];
            tparams[0] = tp;

            for (size_t j = 0; j < tempdecl.parameters.dim; j++)
            {
                // Skip cases like: X(T : T)
                if (i == j)
                    continue;

                if (TemplateTypeParameter ttp = (*tempdecl.parameters)[j].isTemplateTypeParameter())
                {
                    if (reliesOnTident(ttp.specType, &tparams))
                        tp.dependent = true;
                }
                else if (TemplateAliasParameter tap = (*tempdecl.parameters)[j].isTemplateAliasParameter())
                {
                    if (reliesOnTident(tap.specType, &tparams) ||
                        reliesOnTident(isType(tap.specAlias), &tparams))
                    {
                        tp.dependent = true;
                    }
                }
            }
        }

        paramscope.pop();

        // Compute again
        tempdecl.onemember = null;
        if (tempdecl.members)
        {
            Dsymbol s;
            if (Dsymbol.oneMembers(tempdecl.members, &s, tempdecl.ident) && s)
            {
                tempdecl.onemember = s;
                s.parent = tempdecl;
            }
        }

        /* BUG: should check:
         *  o no virtual functions or non-static data members of classes
         */

        tempdecl.semanticRun = PASSsemanticdone;
    }

    override void visit(TemplateInstance ti)
    {
        templateInstanceSemantic(ti, sc, null);
    }

    override void visit(TemplateMixin tm)
    {
        static if (LOG)
        {
            printf("+TemplateMixin.semantic('%s', this=%p)\n",tm.toChars(), tm);
            fflush(stdout);
        }
        if (tm.semanticRun != PASSinit)
        {
            // When a class/struct contains mixin members, and is done over
            // because of forward references, never reach here so semanticRun
            // has been reset to PASSinit.
            static if (LOG)
            {
                printf("\tsemantic done\n");
            }
            return;
        }
        tm.semanticRun = PASSsemantic;
        static if (LOG)
        {
            printf("\tdo semantic\n");
        }

        Scope* scx = null;
        if (tm._scope)
        {
            sc = tm._scope;
            scx = tm._scope; // save so we don't make redundant copies
            tm._scope = null;
        }

        /* Run semantic on each argument, place results in tiargs[],
         * then find best match template with tiargs
         */
        if (!tm.findTempDecl(sc) || !tm.semanticTiargs(sc) || !tm.findBestMatch(sc, null))
        {
            if (tm.semanticRun == PASSinit) // forward reference had occurred
            {
                //printf("forward reference - deferring\n");
                tm._scope = scx ? scx : sc.copy();
                tm._scope.setNoFree();
                tm._scope._module.addDeferredSemantic(tm);
                return;
            }

            tm.inst = tm;
            tm.errors = true;
            return; // error recovery
        }

        auto tempdecl = tm.tempdecl.isTemplateDeclaration();
        assert(tempdecl);

        if (!tm.ident)
        {
            /* Assign scope local unique identifier, as same as lambdas.
             */
            const(char)* s = "__mixin";

            DsymbolTable symtab;
            if (FuncDeclaration func = sc.parent.isFuncDeclaration())
            {
                tm.symtab = func.localsymtab;
                if (tm.symtab)
                {
                    // Inside template constraint, symtab is not set yet.
                    goto L1;
                }
            }
            else
            {
                tm.symtab = sc.parent.isScopeDsymbol().symtab;
            L1:
                assert(tm.symtab);
                tm.ident = Identifier.generateId(s, tm.symtab.len + 1);
                tm.symtab.insert(tm);
            }
        }

        tm.inst = tm;
        tm.parent = sc.parent;

        /* Detect recursive mixin instantiations.
         */
        for (Dsymbol s = tm.parent; s; s = s.parent)
        {
            //printf("\ts = '%s'\n", s.toChars());
            TemplateMixin tmix = s.isTemplateMixin();
            if (!tmix || tempdecl != tmix.tempdecl)
                continue;

            /* Different argument list lengths happen with variadic args
             */
            if (tm.tiargs.dim != tmix.tiargs.dim)
                continue;

            for (size_t i = 0; i < tm.tiargs.dim; i++)
            {
                RootObject o = (*tm.tiargs)[i];
                Type ta = isType(o);
                Expression ea = isExpression(o);
                Dsymbol sa = isDsymbol(o);
                RootObject tmo = (*tmix.tiargs)[i];
                if (ta)
                {
                    Type tmta = isType(tmo);
                    if (!tmta)
                        goto Lcontinue;
                    if (!ta.equals(tmta))
                        goto Lcontinue;
                }
                else if (ea)
                {
                    Expression tme = isExpression(tmo);
                    if (!tme || !ea.equals(tme))
                        goto Lcontinue;
                }
                else if (sa)
                {
                    Dsymbol tmsa = isDsymbol(tmo);
                    if (sa != tmsa)
                        goto Lcontinue;
                }
                else
                    assert(0);
            }
            tm.error("recursive mixin instantiation");
            return;

        Lcontinue:
            continue;
        }

        // Copy the syntax trees from the TemplateDeclaration
        tm.members = Dsymbol.arraySyntaxCopy(tempdecl.members);
        if (!tm.members)
            return;

        tm.symtab = new DsymbolTable();

        for (Scope* sce = sc; 1; sce = sce.enclosing)
        {
            ScopeDsymbol sds = sce.scopesym;
            if (sds)
            {
                sds.importScope(tm, Prot(PROTpublic));
                break;
            }
        }

        static if (LOG)
        {
            printf("\tcreate scope for template parameters '%s'\n", tm.toChars());
        }
        Scope* scy = sc.push(tm);
        scy.parent = tm;

        tm.argsym = new ScopeDsymbol();
        tm.argsym.parent = scy.parent;
        Scope* argscope = scy.push(tm.argsym);

        uint errorsave = global.errors;

        // Declare each template parameter as an alias for the argument type
        tm.declareParameters(argscope);

        // Add members to enclosing scope, as well as this scope
        for (size_t i = 0; i < tm.members.dim; i++)
        {
            Dsymbol s = (*tm.members)[i];
            s.addMember(argscope, tm);
            //printf("sc.parent = %p, sc.scopesym = %p\n", sc.parent, sc.scopesym);
            //printf("s.parent = %s\n", s.parent.toChars());
        }

        // Do semantic() analysis on template instance members
        static if (LOG)
        {
            printf("\tdo semantic() on template instance members '%s'\n", tm.toChars());
        }
        Scope* sc2 = argscope.push(tm);
        //size_t deferred_dim = Module.deferred.dim;

        static __gshared int nest;
        //printf("%d\n", nest);
        // IN_LLVM replaced: if (++nest > 500)
        if (++nest > global.params.nestedTmpl) // LDC_FIXME: add testcase for this
        {
            global.gag = 0; // ensure error message gets printed
            tm.error("recursive expansion");
            fatal();
        }

        for (size_t i = 0; i < tm.members.dim; i++)
        {
            Dsymbol s = (*tm.members)[i];
            s.setScope(sc2);
        }

        for (size_t i = 0; i < tm.members.dim; i++)
        {
            Dsymbol s = (*tm.members)[i];
            s.importAll(sc2);
        }

        for (size_t i = 0; i < tm.members.dim; i++)
        {
            Dsymbol s = (*tm.members)[i];
            s.semantic(sc2);
        }

        nest--;

        /* In DeclDefs scope, TemplateMixin does not have to handle deferred symbols.
         * Because the members would already call Module.addDeferredSemantic() for themselves.
         * See Struct, Class, Interface, and EnumDeclaration.semantic().
         */
        //if (!sc.func && Module.deferred.dim > deferred_dim) {}

        AggregateDeclaration ad = tm.toParent().isAggregateDeclaration();
        if (sc.func && !ad)
        {
            tm.semantic2(sc2);
            tm.semantic3(sc2);
        }

        // Give additional context info if error occurred during instantiation
        if (global.errors != errorsave)
        {
            tm.error("error instantiating");
            tm.errors = true;
        }

        sc2.pop();
        argscope.pop();
        scy.pop();

        static if (LOG)
        {
            printf("-TemplateMixin.semantic('%s', this=%p)\n", tm.toChars(), tm);
        }
    }

    override void visit(Nspace ns)
    {
        if (ns.semanticRun != PASSinit)
            return;
        static if (LOG)
        {
            printf("+Nspace::semantic('%s')\n", ns.toChars());
        }
        if (ns._scope)
        {
            sc = ns._scope;
            ns._scope = null;
        }
        if (!sc)
            return;

        ns.semanticRun = PASSsemantic;
        ns.parent = sc.parent;
        if (ns.members)
        {
            assert(sc);
            sc = sc.push(ns);
            sc.linkage = LINKcpp; // note that namespaces imply C++ linkage
            sc.parent = ns;
            foreach (s; *ns.members)
            {
                s.importAll(sc);
            }
            foreach (s; *ns.members)
            {
                static if (LOG)
                {
                    printf("\tmember '%s', kind = '%s'\n", s.toChars(), s.kind());
                }
                s.semantic(sc);
            }
            sc.pop();
        }
        ns.semanticRun = PASSsemanticdone;
        static if (LOG)
        {
            printf("-Nspace::semantic('%s')\n", ns.toChars());
        }
    }

    void funcDeclarationSemantic(FuncDeclaration funcdecl)
    {
        TypeFunction f;
        AggregateDeclaration ad;
        InterfaceDeclaration id;

        version (none)
        {
            printf("FuncDeclaration::semantic(sc = %p, this = %p, '%s', linkage = %d)\n", sc, funcdecl, funcdecl.toPrettyChars(), sc.linkage);
            if (funcdecl.isFuncLiteralDeclaration())
                printf("\tFuncLiteralDeclaration()\n");
            printf("sc.parent = %s, parent = %s\n", sc.parent.toChars(), funcdecl.parent ? funcdecl.parent.toChars() : "");
            printf("type: %p, %s\n", funcdecl.type, funcdecl.type.toChars());
        }

        if (funcdecl.semanticRun != PASSinit && funcdecl.isFuncLiteralDeclaration())
        {
            /* Member functions that have return types that are
             * forward references can have semantic() run more than
             * once on them.
             * See test\interface2.d, test20
             */
            return;
        }

        if (funcdecl.semanticRun >= PASSsemanticdone)
            return;
        assert(funcdecl.semanticRun <= PASSsemantic);
        funcdecl.semanticRun = PASSsemantic;

        if (funcdecl._scope)
        {
            sc = funcdecl._scope;
            funcdecl._scope = null;
        }

        if (!sc || funcdecl.errors)
            return;

        funcdecl.parent = sc.parent;
        Dsymbol parent = funcdecl.toParent();

        funcdecl.foverrides.setDim(0); // reset in case semantic() is being retried for this function

        funcdecl.storage_class |= sc.stc & ~STCref;
        ad = funcdecl.isThis();
        // Don't nest structs b/c of generated methods which should not access the outer scopes.
        // https://issues.dlang.org/show_bug.cgi?id=16627
        if (ad && !funcdecl.generated)
        {
            funcdecl.storage_class |= ad.storage_class & (STC_TYPECTOR | STCsynchronized);
            ad.makeNested();
        }
        if (sc.func)
            funcdecl.storage_class |= sc.func.storage_class & STCdisable;
        // Remove prefix storage classes silently.
        if ((funcdecl.storage_class & STC_TYPECTOR) && !(ad || funcdecl.isNested()))
            funcdecl.storage_class &= ~STC_TYPECTOR;

        //printf("function storage_class = x%llx, sc.stc = x%llx, %x\n", storage_class, sc.stc, Declaration::isFinal());

        FuncLiteralDeclaration fld = funcdecl.isFuncLiteralDeclaration();
        if (fld && fld.treq)
        {
            Type treq = fld.treq;
            assert(treq.nextOf().ty == Tfunction);
            if (treq.ty == Tdelegate)
                fld.tok = TOKdelegate;
            else if (treq.ty == Tpointer && treq.nextOf().ty == Tfunction)
                fld.tok = TOKfunction;
            else
                assert(0);
            funcdecl.linkage = treq.nextOf().toTypeFunction().linkage;
        }
        else
            funcdecl.linkage = sc.linkage;
        funcdecl.inlining = sc.inlining;
        funcdecl.protection = sc.protection;
        funcdecl.userAttribDecl = sc.userAttribDecl;
        version(IN_LLVM)
        {
            funcdecl.emitInstrumentation = sc.emitInstrumentation;
        }

        if (!funcdecl.originalType)
            funcdecl.originalType = funcdecl.type.syntaxCopy();
        if (funcdecl.type.ty != Tfunction)
        {
            if (funcdecl.type.ty != Terror)
            {
                funcdecl.error("%s must be a function instead of %s", funcdecl.toChars(), funcdecl.type.toChars());
                funcdecl.type = Type.terror;
            }
            funcdecl.errors = true;
            return;
        }
        if (!funcdecl.type.deco)
        {
            sc = sc.push();
            sc.stc |= funcdecl.storage_class & (STCdisable | STCdeprecated); // forward to function type

            TypeFunction tf = funcdecl.type.toTypeFunction();
            if (sc.func)
            {
                /* If the nesting parent is pure without inference,
                 * then this function defaults to pure too.
                 *
                 *  auto foo() pure {
                 *    auto bar() {}     // become a weak purity function
                 *    class C {         // nested class
                 *      auto baz() {}   // become a weak purity function
                 *    }
                 *
                 *    static auto boo() {}   // typed as impure
                 *    // Even though, boo cannot call any impure functions.
                 *    // See also Expression::checkPurity().
                 *  }
                 */
                if (tf.purity == PUREimpure && (funcdecl.isNested() || funcdecl.isThis()))
                {
                    FuncDeclaration fd = null;
                    for (Dsymbol p = funcdecl.toParent2(); p; p = p.toParent2())
                    {
                        if (AggregateDeclaration adx = p.isAggregateDeclaration())
                        {
                            if (adx.isNested())
                                continue;
                            break;
                        }
                        if ((fd = p.isFuncDeclaration()) !is null)
                            break;
                    }

                    /* If the parent's purity is inferred, then this function's purity needs
                     * to be inferred first.
                     */
                    if (fd && fd.isPureBypassingInference() >= PUREweak && !funcdecl.isInstantiated())
                    {
                        tf.purity = PUREfwdref; // default to pure
                    }
                }
            }

            if (tf.isref)
                sc.stc |= STCref;
            if (tf.isscope)
                sc.stc |= STCscope;
            if (tf.isnothrow)
                sc.stc |= STCnothrow;
            if (tf.isnogc)
                sc.stc |= STCnogc;
            if (tf.isproperty)
                sc.stc |= STCproperty;
            if (tf.purity == PUREfwdref)
                sc.stc |= STCpure;
            if (tf.trust != TRUSTdefault)
                sc.stc &= ~(STCsafe | STCsystem | STCtrusted);
            if (tf.trust == TRUSTsafe)
                sc.stc |= STCsafe;
            if (tf.trust == TRUSTsystem)
                sc.stc |= STCsystem;
            if (tf.trust == TRUSTtrusted)
                sc.stc |= STCtrusted;

            if (funcdecl.isCtorDeclaration())
            {
                sc.flags |= SCOPEctor;
                Type tret = ad.handleType();
                assert(tret);
                tret = tret.addStorageClass(funcdecl.storage_class | sc.stc);
                tret = tret.addMod(funcdecl.type.mod);
                tf.next = tret;
                if (ad.isStructDeclaration())
                    sc.stc |= STCref;
            }

            // 'return' on a non-static class member function implies 'scope' as well
            if (ad && ad.isClassDeclaration() && (tf.isreturn || sc.stc & STCreturn) && !(sc.stc & STCstatic))
                sc.stc |= STCscope;

            // If 'this' has no pointers, remove 'scope' as it has no meaning
            if (sc.stc & STCscope && ad && ad.isStructDeclaration() && !ad.type.hasPointers())
            {
                sc.stc &= ~STCscope;
                tf.isscope = false;
            }

            sc.linkage = funcdecl.linkage;

            if (!tf.isNaked() && !(funcdecl.isThis() || funcdecl.isNested()))
            {
                OutBuffer buf;
                MODtoBuffer(&buf, tf.mod);
                funcdecl.error("without 'this' cannot be %s", buf.peekString());
                tf.mod = 0; // remove qualifiers
            }

            /* Apply const, immutable, wild and shared storage class
             * to the function type. Do this before type semantic.
             */
            auto stc = funcdecl.storage_class;
            if (funcdecl.type.isImmutable())
                stc |= STCimmutable;
            if (funcdecl.type.isConst())
                stc |= STCconst;
            if (funcdecl.type.isShared() || funcdecl.storage_class & STCsynchronized)
                stc |= STCshared;
            if (funcdecl.type.isWild())
                stc |= STCwild;
            funcdecl.type = funcdecl.type.addSTC(stc);

            funcdecl.type = funcdecl.type.typeSemantic(funcdecl.loc, sc);
            sc = sc.pop();
        }
        if (funcdecl.type.ty != Tfunction)
        {
            if (funcdecl.type.ty != Terror)
            {
                funcdecl.error("%s must be a function instead of %s", funcdecl.toChars(), funcdecl.type.toChars());
                funcdecl.type = Type.terror;
            }
            funcdecl.errors = true;
            return;
        }
        else
        {
            // Merge back function attributes into 'originalType'.
            // It's used for mangling, ddoc, and json output.
            TypeFunction tfo = funcdecl.originalType.toTypeFunction();
            TypeFunction tfx = funcdecl.type.toTypeFunction();
            tfo.mod = tfx.mod;
            tfo.isscope = tfx.isscope;
            tfo.isscopeinferred = tfx.isscopeinferred;
            tfo.isref = tfx.isref;
            tfo.isnothrow = tfx.isnothrow;
            tfo.isnogc = tfx.isnogc;
            tfo.isproperty = tfx.isproperty;
            tfo.purity = tfx.purity;
            tfo.trust = tfx.trust;

            funcdecl.storage_class &= ~(STC_TYPECTOR | STC_FUNCATTR);
        }

        f = cast(TypeFunction)funcdecl.type;
        size_t nparams = Parameter.dim(f.parameters);

        if ((funcdecl.storage_class & STCauto) && !f.isref && !funcdecl.inferRetType)
            funcdecl.error("storage class 'auto' has no effect if return type is not inferred");

        /* Functions can only be 'scope' if they have a 'this'
         */
        if (f.isscope && !funcdecl.isNested() && !ad)
        {
            funcdecl.error("functions cannot be scope");
        }

        if (f.isreturn && !funcdecl.needThis() && !funcdecl.isNested())
        {
            /* Non-static nested functions have a hidden 'this' pointer to which
             * the 'return' applies
             */
            funcdecl.error("static member has no 'this' to which 'return' can apply");
        }

        if (funcdecl.isAbstract() && !funcdecl.isVirtual())
        {
            const(char)* sfunc;
            if (funcdecl.isStatic())
                sfunc = "static";
            else if (funcdecl.protection.kind == PROTprivate || funcdecl.protection.kind == PROTpackage)
                sfunc = protectionToChars(funcdecl.protection.kind);
            else
                sfunc = "non-virtual";
            funcdecl.error("%s functions cannot be abstract", sfunc);
        }

        if (funcdecl.isOverride() && !funcdecl.isVirtual())
        {
            PROTKIND kind = funcdecl.prot().kind;
            if ((kind == PROTprivate || kind == PROTpackage) && funcdecl.isMember())
                funcdecl.error("%s method is not virtual and cannot override", protectionToChars(kind));
            else
                funcdecl.error("cannot override a non-virtual function");
        }

        if (funcdecl.isAbstract() && funcdecl.isFinalFunc())
            funcdecl.error("cannot be both final and abstract");
        version (none)
        {
            if (funcdecl.isAbstract() && funcdecl.fbody)
                funcdecl.error("abstract functions cannot have bodies");
        }

        version (none)
        {
            if (funcdecl.isStaticConstructor() || funcdecl.isStaticDestructor())
            {
                if (!funcdecl.isStatic() || funcdecl.type.nextOf().ty != Tvoid)
                    funcdecl.error("static constructors / destructors must be static void");
                if (f.arguments && f.arguments.dim)
                    funcdecl.error("static constructors / destructors must have empty parameter list");
                // BUG: check for invalid storage classes
            }
        }

        id = parent.isInterfaceDeclaration();
        if (id)
        {
            funcdecl.storage_class |= STCabstract;
            if (funcdecl.isCtorDeclaration() || funcdecl.isPostBlitDeclaration() || funcdecl.isDtorDeclaration() || funcdecl.isInvariantDeclaration() || funcdecl.isNewDeclaration() || funcdecl.isDelete())
                funcdecl.error("constructors, destructors, postblits, invariants, new and delete functions are not allowed in interface %s", id.toChars());
            if (funcdecl.fbody && funcdecl.isVirtual())
                funcdecl.error("function body only allowed in final functions in interface %s", id.toChars());
        }
        if (UnionDeclaration ud = parent.isUnionDeclaration())
        {
            if (funcdecl.isPostBlitDeclaration() || funcdecl.isDtorDeclaration() || funcdecl.isInvariantDeclaration())
                funcdecl.error("destructors, postblits and invariants are not allowed in union %s", ud.toChars());
        }

        /* Contracts can only appear without a body when they are virtual interface functions
         */
        if (!funcdecl.fbody && (funcdecl.fensure || funcdecl.frequire) && !(id && funcdecl.isVirtual()))
            funcdecl.error("in and out contracts require function body");

        if (StructDeclaration sd = parent.isStructDeclaration())
        {
            if (funcdecl.isCtorDeclaration())
            {
                goto Ldone;
            }
        }

        if (ClassDeclaration cd = parent.isClassDeclaration())
        {
            if (funcdecl.isCtorDeclaration())
            {
                goto Ldone;
            }

            if (funcdecl.storage_class & STCabstract)
                cd.isabstract = ABSyes;

            // if static function, do not put in vtbl[]
            if (!funcdecl.isVirtual())
            {
                //printf("\tnot virtual\n");
                goto Ldone;
            }
            // Suppress further errors if the return type is an error
            if (funcdecl.type.nextOf() == Type.terror)
                goto Ldone;

            bool may_override = false;
            for (size_t i = 0; i < cd.baseclasses.dim; i++)
            {
                BaseClass* b = (*cd.baseclasses)[i];
                ClassDeclaration cbd = b.type.toBasetype().isClassHandle();
                if (!cbd)
                    continue;
                for (size_t j = 0; j < cbd.vtbl.dim; j++)
                {
                    FuncDeclaration f2 = cbd.vtbl[j].isFuncDeclaration();
                    if (!f2 || f2.ident != funcdecl.ident)
                        continue;
                    if (cbd.parent && cbd.parent.isTemplateInstance())
                    {
                        if (!f2.functionSemantic())
                            goto Ldone;
                    }
                    may_override = true;
                }
            }
            if (may_override && funcdecl.type.nextOf() is null)
            {
                /* If same name function exists in base class but 'this' is auto return,
                 * cannot find index of base class's vtbl[] to override.
                 */
                funcdecl.error("return type inference is not supported if may override base class function");
            }

            /* Find index of existing function in base class's vtbl[] to override
             * (the index will be the same as in cd's current vtbl[])
             */
            int vi = cd.baseClass ? funcdecl.findVtblIndex(&cd.baseClass.vtbl, cast(int)cd.baseClass.vtbl.dim) : -1;

            bool doesoverride = false;
            switch (vi)
            {
            case -1:
            Lintro:
                /* Didn't find one, so
                 * This is an 'introducing' function which gets a new
                 * slot in the vtbl[].
                 */

                // Verify this doesn't override previous final function
                if (cd.baseClass)
                {
                    Dsymbol s = cd.baseClass.search(funcdecl.loc, funcdecl.ident);
                    if (s)
                    {
                        FuncDeclaration f2 = s.isFuncDeclaration();
                        if (f2)
                        {
                            f2 = f2.overloadExactMatch(funcdecl.type);
                            if (f2 && f2.isFinalFunc() && f2.prot().kind != PROTprivate)
                                funcdecl.error("cannot override final function %s", f2.toPrettyChars());
                        }
                    }
                }

                /* These quirky conditions mimic what VC++ appears to do
                 */
                if (global.params.mscoff && cd.cpp &&
                    cd.baseClass && cd.baseClass.vtbl.dim)
                {
                    /* if overriding an interface function, then this is not
                     * introducing and don't put it in the class vtbl[]
                     */
                    funcdecl.interfaceVirtual = funcdecl.overrideInterface();
                    if (funcdecl.interfaceVirtual)
                    {
                        //printf("\tinterface function %s\n", toChars());
                        cd.vtblFinal.push(funcdecl);
                        goto Linterfaces;
                    }
                }

                if (funcdecl.isFinalFunc())
                {
                    // Don't check here, as it may override an interface function
                    //if (isOverride())
                    //    error("is marked as override, but does not override any function");
                    cd.vtblFinal.push(funcdecl);
                }
                else
                {
                    //printf("\tintroducing function %s\n", toChars());
                    funcdecl.introducing = 1;
                    if (cd.cpp && Target.reverseCppOverloads)
                    {
                        // with dmc, overloaded functions are grouped and in reverse order
                        funcdecl.vtblIndex = cast(int)cd.vtbl.dim;
                        for (size_t i = 0; i < cd.vtbl.dim; i++)
                        {
                            if (cd.vtbl[i].ident == funcdecl.ident && cd.vtbl[i].parent == parent)
                            {
                                funcdecl.vtblIndex = cast(int)i;
                                break;
                            }
                        }
                        // shift all existing functions back
                        for (size_t i = cd.vtbl.dim; i > funcdecl.vtblIndex; i--)
                        {
                            FuncDeclaration fd = cd.vtbl[i - 1].isFuncDeclaration();
                            assert(fd);
                            fd.vtblIndex++;
                        }
                        cd.vtbl.insert(funcdecl.vtblIndex, funcdecl);
                    }
                    else
                    {
                        // Append to end of vtbl[]
                        vi = cast(int)cd.vtbl.dim;
                        cd.vtbl.push(funcdecl);
                        funcdecl.vtblIndex = vi;
                    }
                }
                break;

            case -2:
                // can't determine because of forward references
                funcdecl.errors = true;
                return;

            default:
                {
                    FuncDeclaration fdv = cd.baseClass.vtbl[vi].isFuncDeclaration();
                    FuncDeclaration fdc = cd.vtbl[vi].isFuncDeclaration();
                    // This function is covariant with fdv

                    if (fdc == funcdecl)
                    {
                        doesoverride = true;
                        break;
                    }

                    if (fdc.toParent() == parent)
                    {
                        //printf("vi = %d,\tthis = %p %s %s @ [%s]\n\tfdc  = %p %s %s @ [%s]\n\tfdv  = %p %s %s @ [%s]\n",
                        //        vi, this, this.toChars(), this.type.toChars(), this.loc.toChars(),
                        //            fdc,  fdc .toChars(), fdc .type.toChars(), fdc .loc.toChars(),
                        //            fdv,  fdv .toChars(), fdv .type.toChars(), fdv .loc.toChars());

                        // fdc overrides fdv exactly, then this introduces new function.
                        if (fdc.type.mod == fdv.type.mod && funcdecl.type.mod != fdv.type.mod)
                            goto Lintro;
                    }

                    // This function overrides fdv
                    if (fdv.isFinalFunc())
                        funcdecl.error("cannot override final function %s", fdv.toPrettyChars());

                    if (!funcdecl.isOverride())
                    {
                        if (fdv.isFuture())
                        {
                            deprecation(funcdecl.loc, "@future base class method %s is being overridden by %s; rename the latter", fdv.toPrettyChars(), funcdecl.toPrettyChars());
                            // Treat 'this' as an introducing function, giving it a separate hierarchy in the vtbl[]
                            goto Lintro;
                        }
                        else
                        {
                            int vi2 = funcdecl.findVtblIndex(&cd.baseClass.vtbl, cast(int)cd.baseClass.vtbl.dim, false);
                            if (vi2 < 0)
                                // https://issues.dlang.org/show_bug.cgi?id=17349
                                deprecation(funcdecl.loc, "cannot implicitly override base class method `%s` with `%s`; add `override` attribute", fdv.toPrettyChars(), funcdecl.toPrettyChars());
                            else
                                error(funcdecl.loc, "cannot implicitly override base class method %s with %s; add 'override' attribute", fdv.toPrettyChars(), funcdecl.toPrettyChars());
                        }
                    }
                    doesoverride = true;
                    if (fdc.toParent() == parent)
                    {
                        // If both are mixins, or both are not, then error.
                        // If either is not, the one that is not overrides the other.
                        bool thismixin = funcdecl.parent.isClassDeclaration() !is null;
                        bool fdcmixin = fdc.parent.isClassDeclaration() !is null;
                        if (thismixin == fdcmixin)
                        {
                            funcdecl.error("multiple overrides of same function");
                        }
                        else if (!thismixin) // fdc overrides fdv
                        {
                            // this doesn't override any function
                            break;
                        }
                    }
                    cd.vtbl[vi] = funcdecl;
                    funcdecl.vtblIndex = vi;

                    /* Remember which functions this overrides
                     */
                    funcdecl.foverrides.push(fdv);

                    /* This works by whenever this function is called,
                     * it actually returns tintro, which gets dynamically
                     * cast to type. But we know that tintro is a base
                     * of type, so we could optimize it by not doing a
                     * dynamic cast, but just subtracting the isBaseOf()
                     * offset if the value is != null.
                     */

                    if (fdv.tintro)
                        funcdecl.tintro = fdv.tintro;
                    else if (!funcdecl.type.equals(fdv.type))
                    {
                        /* Only need to have a tintro if the vptr
                         * offsets differ
                         */
                        int offset;
                        if (fdv.type.nextOf().isBaseOf(funcdecl.type.nextOf(), &offset))
                        {
                            funcdecl.tintro = fdv.type;
                        }
                    }
                    break;
                }
            }

            /* Go through all the interface bases.
             * If this function is covariant with any members of those interface
             * functions, set the tintro.
             */
        Linterfaces:
            foreach (b; cd.interfaces)
            {
                vi = funcdecl.findVtblIndex(&b.sym.vtbl, cast(int)b.sym.vtbl.dim);
                switch (vi)
                {
                case -1:
                    break;

                case -2:
                    // can't determine because of forward references
                    funcdecl.errors = true;
                    return;

                default:
                    {
                        auto fdv = cast(FuncDeclaration)b.sym.vtbl[vi];
                        Type ti = null;

                        /* Remember which functions this overrides
                         */
                        funcdecl.foverrides.push(fdv);

                        /* Should we really require 'override' when implementing
                         * an interface function?
                         */
                        //if (!isOverride())
                        //    warning(loc, "overrides base class function %s, but is not marked with 'override'", fdv.toPrettyChars());

                        if (fdv.tintro)
                            ti = fdv.tintro;
                        else if (!funcdecl.type.equals(fdv.type))
                        {
                            /* Only need to have a tintro if the vptr
                             * offsets differ
                             */
                            int offset;
                            if (fdv.type.nextOf().isBaseOf(funcdecl.type.nextOf(), &offset))
                            {
                                ti = fdv.type;
                            }
                        }
                        if (ti)
                        {
                            if (funcdecl.tintro)
                            {
                                if (!funcdecl.tintro.nextOf().equals(ti.nextOf()) && !funcdecl.tintro.nextOf().isBaseOf(ti.nextOf(), null) && !ti.nextOf().isBaseOf(funcdecl.tintro.nextOf(), null))
                                {
                                    funcdecl.error("incompatible covariant types %s and %s", funcdecl.tintro.toChars(), ti.toChars());
                                }
                            }
                            funcdecl.tintro = ti;
                        }
                        goto L2;
                    }
                }
            }

            if (!doesoverride && funcdecl.isOverride() && (funcdecl.type.nextOf() || !may_override))
            {
                BaseClass* bc = null;
                Dsymbol s = null;
                for (size_t i = 0; i < cd.baseclasses.dim; i++)
                {
                    bc = (*cd.baseclasses)[i];
                    s = bc.sym.search_correct(funcdecl.ident);
                    if (s)
                        break;
                }

                if (s)
                    funcdecl.error("does not override any function, did you mean to override '%s%s'?",
                        bc.sym.isCPPclass() ? "extern (C++) ".ptr : "".ptr, s.toPrettyChars());
                else
                    funcdecl.error("does not override any function");
            }

        L2:
            /* Go through all the interface bases.
             * Disallow overriding any final functions in the interface(s).
             */
            foreach (b; cd.interfaces)
            {
                if (b.sym)
                {
                    Dsymbol s = search_function(b.sym, funcdecl.ident);
                    if (s)
                    {
                        FuncDeclaration f2 = s.isFuncDeclaration();
                        if (f2)
                        {
                            f2 = f2.overloadExactMatch(funcdecl.type);
                            if (f2 && f2.isFinalFunc() && f2.prot().kind != PROTprivate)
                                funcdecl.error("cannot override final function %s.%s", b.sym.toChars(), f2.toPrettyChars());
                        }
                    }
                }
            }

            if (funcdecl.isOverride)
            {
                if (funcdecl.storage_class & STCdisable)
                    funcdecl.deprecation("overridden functions cannot be annotated @disable");
                if (funcdecl.isDeprecated)
                    funcdecl.deprecation("deprecated functions cannot be annotated @disable");
            }

        }
        else if (funcdecl.isOverride() && !parent.isTemplateInstance())
            funcdecl.error("override only applies to class member functions");

        // Reflect this.type to f because it could be changed by findVtblIndex
        f = funcdecl.type.toTypeFunction();

        /* Do not allow template instances to add virtual functions
         * to a class.
         */
        if (funcdecl.isVirtual())
        {
            TemplateInstance ti = parent.isTemplateInstance();
            if (ti)
            {
                // Take care of nested templates
                while (1)
                {
                    TemplateInstance ti2 = ti.tempdecl.parent.isTemplateInstance();
                    if (!ti2)
                        break;
                    ti = ti2;
                }

                // If it's a member template
                ClassDeclaration cd = ti.tempdecl.isClassMember();
                if (cd)
                {
                    funcdecl.error("cannot use template to add virtual function to class '%s'", cd.toChars());
                }
            }
        }

        if (funcdecl.isMain())
            funcdecl.checkDmain();       // Check main() parameters and return type

    Ldone:
        /* Purity and safety can be inferred for some functions by examining
         * the function body.
         */
        if (funcdecl.canInferAttributes(sc))
            funcdecl.initInferAttributes();

        Module.dprogress++;
        version(IN_LLVM)
        {
            // LDC relies on semanticRun variable not being reset here
            if (funcdecl.semanticRun < PASSsemanticdone)
                funcdecl.semanticRun = PASSsemanticdone;
        }
        else
        {
            funcdecl.semanticRun = PASSsemanticdone;
        }

        /* Save scope for possible later use (if we need the
         * function internals)
         */
        funcdecl._scope = sc.copy();
        funcdecl._scope.setNoFree();

        static __gshared bool printedMain = false; // semantic might run more than once
        if (global.params.verbose && !printedMain)
        {
            const(char)* type = funcdecl.isMain() ? "main" : funcdecl.isWinMain() ? "winmain" : funcdecl.isDllMain() ? "dllmain" : cast(const(char)*)null;
            Module mod = sc._module;

            if (type && mod)
            {
                printedMain = true;
                const(char)* name = FileName.searchPath(global.path, mod.srcfile.toChars(), true);
                fprintf(global.stdmsg, "entry     %-10s\t%s\n", type, name);
            }
        }

        if (funcdecl.fbody && funcdecl.isMain() && sc._module.isRoot())
            genCmain(sc);

        assert(funcdecl.type.ty != Terror || funcdecl.errors);
    }

     /// Do the semantic analysis on the external interface to the function.
    override void visit(FuncDeclaration funcdecl)
    {
        funcDeclarationSemantic(funcdecl);
    }

    override void visit(CtorDeclaration ctd)
    {
        //printf("CtorDeclaration::semantic() %s\n", toChars());
        if (ctd.semanticRun >= PASSsemanticdone)
            return;
        if (ctd._scope)
        {
            sc = ctd._scope;
            ctd._scope = null;
        }

        ctd.parent = sc.parent;
        Dsymbol p = ctd.toParent2();
        AggregateDeclaration ad = p.isAggregateDeclaration();
        if (!ad)
        {
            error(ctd.loc, "constructor can only be a member of aggregate, not %s %s", p.kind(), p.toChars());
            ctd.type = Type.terror;
            ctd.errors = true;
            return;
        }

        sc = sc.push();
        sc.stc &= ~STCstatic; // not a static constructor
        sc.flags |= SCOPEctor;

        funcDeclarationSemantic(ctd);

        sc.pop();

        if (ctd.errors)
            return;

        TypeFunction tf = ctd.type.toTypeFunction();

        /* See if it's the default constructor
         * But, template constructor should not become a default constructor.
         */
        if (ad && (!ctd.parent.isTemplateInstance() || ctd.parent.isTemplateMixin()))
        {
            immutable dim = Parameter.dim(tf.parameters);

            if (auto sd = ad.isStructDeclaration())
            {
                if (dim == 0 && tf.varargs == 0) // empty default ctor w/o any varargs
                {
                    if (ctd.fbody || !(ctd.storage_class & STCdisable))
                    {
                        ctd.error("default constructor for structs only allowed " ~
                            "with @disable, no body, and no parameters");
                        ctd.storage_class |= STCdisable;
                        ctd.fbody = null;
                    }
                    sd.noDefaultCtor = true;
                }
                else if (dim == 0 && tf.varargs) // allow varargs only ctor
                {
                }
                else if (dim && Parameter.getNth(tf.parameters, 0).defaultArg)
                {
                    // if the first parameter has a default argument, then the rest does as well
                    if (ctd.storage_class & STCdisable)
                    {
                        ctd.deprecation("@disable'd constructor cannot have default "~
                                    "arguments for all parameters.");
                        deprecationSupplemental(ctd.loc, "Use @disable this(); if you want to disable default initialization.");
                    }
                    else
                        ctd.deprecation("all parameters have default arguments, "~
                                    "but structs cannot have default constructors.");
                }
            }
            else if (dim == 0 && tf.varargs == 0)
            {
                ad.defaultCtor = ctd;
            }
        }
    }

    override void visit(PostBlitDeclaration pbd)
    {
        //printf("PostBlitDeclaration::semantic() %s\n", toChars());
        //printf("ident: %s, %s, %p, %p\n", ident.toChars(), Id::dtor.toChars(), ident, Id::dtor);
        //printf("stc = x%llx\n", sc.stc);
        if (pbd.semanticRun >= PASSsemanticdone)
            return;
        if (pbd._scope)
        {
            sc = pbd._scope;
            pbd._scope = null;
        }

        pbd.parent = sc.parent;
        Dsymbol p = pbd.toParent2();
        StructDeclaration ad = p.isStructDeclaration();
        if (!ad)
        {
            error(pbd.loc, "postblit can only be a member of struct/union, not %s %s", p.kind(), p.toChars());
            pbd.type = Type.terror;
            pbd.errors = true;
            return;
        }
        if (pbd.ident == Id.postblit && pbd.semanticRun < PASSsemantic)
            ad.postblits.push(pbd);
        if (!pbd.type)
            pbd.type = new TypeFunction(null, Type.tvoid, false, LINKd, pbd.storage_class);

        sc = sc.push();
        sc.stc &= ~STCstatic; // not static
        sc.linkage = LINKd;

        funcDeclarationSemantic(pbd);

        sc.pop();
    }

    override void visit(DtorDeclaration dd)
    {
        //printf("DtorDeclaration::semantic() %s\n", toChars());
        //printf("ident: %s, %s, %p, %p\n", ident.toChars(), Id::dtor.toChars(), ident, Id::dtor);
        if (dd.semanticRun >= PASSsemanticdone)
            return;
        if (dd._scope)
        {
            sc = dd._scope;
            dd._scope = null;
        }

        dd.parent = sc.parent;
        Dsymbol p = dd.toParent2();
        AggregateDeclaration ad = p.isAggregateDeclaration();
        if (!ad)
        {
            error(dd.loc, "destructor can only be a member of aggregate, not %s %s", p.kind(), p.toChars());
            dd.type = Type.terror;
            dd.errors = true;
            return;
        }
        if (dd.ident == Id.dtor && dd.semanticRun < PASSsemantic)
            ad.dtors.push(dd);
        if (!dd.type)
            dd.type = new TypeFunction(null, Type.tvoid, false, LINKd, dd.storage_class);

        sc = sc.push();
        sc.stc &= ~STCstatic; // not a static destructor
        if (sc.linkage != LINKcpp)
            sc.linkage = LINKd;

        funcDeclarationSemantic(dd);

        sc.pop();
    }

    override void visit(StaticCtorDeclaration scd)
    {
        //printf("StaticCtorDeclaration::semantic()\n");
        if (scd.semanticRun >= PASSsemanticdone)
            return;
        if (scd._scope)
        {
            sc = scd._scope;
            scd._scope = null;
        }

        scd.parent = sc.parent;
        Dsymbol p = scd.parent.pastMixin();
        if (!p.isScopeDsymbol())
        {
            const(char)* s = (scd.isSharedStaticCtorDeclaration() ? "shared " : "");
            error(scd.loc, "%sstatic constructor can only be member of module/aggregate/template, not %s %s", s, p.kind(), p.toChars());
            scd.type = Type.terror;
            scd.errors = true;
            return;
        }
        if (!scd.type)
            scd.type = new TypeFunction(null, Type.tvoid, false, LINKd, scd.storage_class);

        /* If the static ctor appears within a template instantiation,
         * it could get called multiple times by the module constructors
         * for different modules. Thus, protect it with a gate.
         */
        if (scd.isInstantiated() && scd.semanticRun < PASSsemantic)
        {
            /* Add this prefix to the function:
             *      static int gate;
             *      if (++gate != 1) return;
             * Note that this is not thread safe; should not have threads
             * during static construction.
             */
            auto v = new VarDeclaration(Loc(), Type.tint32, Id.gate, null);
            v.storage_class = STCtemp | (scd.isSharedStaticCtorDeclaration() ? STCstatic : STCtls);

            auto sa = new Statements();
            Statement s = new ExpStatement(Loc(), v);
            sa.push(s);

            Expression e = new IdentifierExp(Loc(), v.ident);
            e = new AddAssignExp(Loc(), e, new IntegerExp(1));
            e = new EqualExp(TOKnotequal, Loc(), e, new IntegerExp(1));
            s = new IfStatement(Loc(), null, e, new ReturnStatement(Loc(), null), null, Loc());

            sa.push(s);
            if (scd.fbody)
                sa.push(scd.fbody);

            scd.fbody = new CompoundStatement(Loc(), sa);
        }

        funcDeclarationSemantic(scd);

        // We're going to need ModuleInfo
        Module m = scd.getModule();
        if (!m)
            m = sc._module;
        if (m)
        {
            m.needmoduleinfo = 1;
            //printf("module1 %s needs moduleinfo\n", m.toChars());
        }
    }

    override void visit(StaticDtorDeclaration sdd)
    {
        if (sdd.semanticRun >= PASSsemanticdone)
            return;
        if (sdd._scope)
        {
            sc = sdd._scope;
            sdd._scope = null;
        }

        sdd.parent = sc.parent;
        Dsymbol p = sdd.parent.pastMixin();
        if (!p.isScopeDsymbol())
        {
            const(char)* s = (sdd.isSharedStaticDtorDeclaration() ? "shared " : "");
            error(sdd.loc, "%sstatic destructor can only be member of module/aggregate/template, not %s %s", s, p.kind(), p.toChars());
            sdd.type = Type.terror;
            sdd.errors = true;
            return;
        }
        if (!sdd.type)
            sdd.type = new TypeFunction(null, Type.tvoid, false, LINKd, sdd.storage_class);

        /* If the static ctor appears within a template instantiation,
         * it could get called multiple times by the module constructors
         * for different modules. Thus, protect it with a gate.
         */
        if (sdd.isInstantiated() && sdd.semanticRun < PASSsemantic)
        {
            /* Add this prefix to the function:
             *      static int gate;
             *      if (--gate != 0) return;
             * Increment gate during constructor execution.
             * Note that this is not thread safe; should not have threads
             * during static destruction.
             */
            auto v = new VarDeclaration(Loc(), Type.tint32, Id.gate, null);
            v.storage_class = STCtemp | (sdd.isSharedStaticDtorDeclaration() ? STCstatic : STCtls);

            auto sa = new Statements();
            Statement s = new ExpStatement(Loc(), v);
            sa.push(s);

            Expression e = new IdentifierExp(Loc(), v.ident);
            e = new AddAssignExp(Loc(), e, new IntegerExp(-1));
            e = new EqualExp(TOKnotequal, Loc(), e, new IntegerExp(0));
            s = new IfStatement(Loc(), null, e, new ReturnStatement(Loc(), null), null, Loc());

            sa.push(s);
            if (sdd.fbody)
                sa.push(sdd.fbody);

            sdd.fbody = new CompoundStatement(Loc(), sa);

            sdd.vgate = v;
        }

        funcDeclarationSemantic(sdd);

        // We're going to need ModuleInfo
        Module m = sdd.getModule();
        if (!m)
            m = sc._module;
        if (m)
        {
            m.needmoduleinfo = 1;
            //printf("module2 %s needs moduleinfo\n", m.toChars());
        }
    }

    override void visit(InvariantDeclaration invd)
    {
        if (invd.semanticRun >= PASSsemanticdone)
            return;
        if (invd._scope)
        {
            sc = invd._scope;
            invd._scope = null;
        }

        invd.parent = sc.parent;
        Dsymbol p = invd.parent.pastMixin();
        AggregateDeclaration ad = p.isAggregateDeclaration();
        if (!ad)
        {
            error(invd.loc, "invariant can only be a member of aggregate, not %s %s", p.kind(), p.toChars());
            invd.type = Type.terror;
            invd.errors = true;
            return;
        }
        if (invd.ident != Id.classInvariant &&
             invd.semanticRun < PASSsemantic &&
             !ad.isUnionDeclaration()           // users are on their own with union fields
           )
            ad.invs.push(invd);
        if (!invd.type)
            invd.type = new TypeFunction(null, Type.tvoid, false, LINKd, invd.storage_class);

        sc = sc.push();
        sc.stc &= ~STCstatic; // not a static invariant
        sc.stc |= STCconst; // invariant() is always const
        sc.flags = (sc.flags & ~SCOPEcontract) | SCOPEinvariant;
        sc.linkage = LINKd;

        funcDeclarationSemantic(invd);

        sc.pop();
    }

    override void visit(UnitTestDeclaration utd)
    {
        // The identifier has to be generated here in order for it to be possible
        // to link regardless of whether the files were compiled separately
        // or all at once. See:
        // https://issues.dlang.org/show_bug.cgi?id=16995
        utd.setIdentifier();

        if (utd.semanticRun >= PASSsemanticdone)
            return;
        if (utd._scope)
        {
            sc = utd._scope;
            utd._scope = null;
        }

        utd.protection = sc.protection;

        utd.parent = sc.parent;
        Dsymbol p = utd.parent.pastMixin();
        if (!p.isScopeDsymbol())
        {
            error(utd.loc, "unittest can only be a member of module/aggregate/template, not %s %s", p.kind(), p.toChars());
            utd.type = Type.terror;
            utd.errors = true;
            return;
        }

        if (global.params.useUnitTests)
        {
            if (!utd.type)
                utd.type = new TypeFunction(null, Type.tvoid, false, LINKd, utd.storage_class);
            Scope* sc2 = sc.push();
            sc2.linkage = LINKd;
            funcDeclarationSemantic(utd);
            sc2.pop();
        }

        version (none)
        {
            // We're going to need ModuleInfo even if the unit tests are not
            // compiled in, because other modules may import this module and refer
            // to this ModuleInfo.
            // (This doesn't make sense to me?)
            Module m = utd.getModule();
            if (!m)
                m = sc._module;
            if (m)
            {
                //printf("module3 %s needs moduleinfo\n", m.toChars());
                m.needmoduleinfo = 1;
            }
        }
    }

    override void visit(NewDeclaration nd)
    {
        //printf("NewDeclaration::semantic()\n");
        if (nd.semanticRun >= PASSsemanticdone)
            return;
        if (nd._scope)
        {
            sc = nd._scope;
            nd._scope = null;
        }

        nd.parent = sc.parent;
        Dsymbol p = nd.parent.pastMixin();
        if (!p.isAggregateDeclaration())
        {
            error(nd.loc, "allocator can only be a member of aggregate, not %s %s", p.kind(), p.toChars());
            nd.type = Type.terror;
            nd.errors = true;
            return;
        }
        Type tret = Type.tvoid.pointerTo();
        if (!nd.type)
            nd.type = new TypeFunction(nd.parameters, tret, nd.varargs, LINKd, nd.storage_class);

        nd.type = nd.type.typeSemantic(nd.loc, sc);

        // Check that there is at least one argument of type size_t
        TypeFunction tf = nd.type.toTypeFunction();
        if (Parameter.dim(tf.parameters) < 1)
        {
            nd.error("at least one argument of type size_t expected");
        }
        else
        {
            Parameter fparam = Parameter.getNth(tf.parameters, 0);
            if (!fparam.type.equals(Type.tsize_t))
                nd.error("first argument must be type size_t, not %s", fparam.type.toChars());
        }

        funcDeclarationSemantic(nd);
    }

    override void visit(DeleteDeclaration deld)
    {
        //printf("DeleteDeclaration::semantic()\n");
        if (deld.semanticRun >= PASSsemanticdone)
            return;
        if (deld._scope)
        {
            sc = deld._scope;
            deld._scope = null;
        }

        deld.parent = sc.parent;
        Dsymbol p = deld.parent.pastMixin();
        if (!p.isAggregateDeclaration())
        {
            error(deld.loc, "deallocator can only be a member of aggregate, not %s %s", p.kind(), p.toChars());
            deld.type = Type.terror;
            deld.errors = true;
            return;
        }
        if (!deld.type)
            deld.type = new TypeFunction(deld.parameters, Type.tvoid, 0, LINKd, deld.storage_class);

        deld.type = deld.type.typeSemantic(deld.loc, sc);

        // Check that there is only one argument of type void*
        TypeFunction tf = deld.type.toTypeFunction();
        if (Parameter.dim(tf.parameters) != 1)
        {
            deld.error("one argument of type void* expected");
        }
        else
        {
            Parameter fparam = Parameter.getNth(tf.parameters, 0);
            if (!fparam.type.equals(Type.tvoid.pointerTo()))
                deld.error("one argument of type void* expected, not %s", fparam.type.toChars());
        }

        funcDeclarationSemantic(deld);
    }

    override void visit(StructDeclaration sd)
    {
        //printf("StructDeclaration::semantic(this=%p, '%s', sizeok = %d)\n", this, toPrettyChars(), sizeok);

        //static int count; if (++count == 20) assert(0);

        if (sd.semanticRun >= PASSsemanticdone)
            return;
        int errors = global.errors;

        //printf("+StructDeclaration::semantic(this=%p, '%s', sizeok = %d)\n", this, toPrettyChars(), sizeok);
        Scope* scx = null;
        if (sd._scope)
        {
            sc = sd._scope;
            scx = sd._scope; // save so we don't make redundant copies
            sd._scope = null;
        }

        if (!sd.parent)
        {
            assert(sc.parent && sc.func);
            sd.parent = sc.parent;
        }
        assert(sd.parent && !sd.isAnonymous());

        if (sd.errors)
            sd.type = Type.terror;
        if (sd.semanticRun == PASSinit)
            sd.type = sd.type.addSTC(sc.stc | sd.storage_class);
        sd.type = sd.type.typeSemantic(sd.loc, sc);
        if (sd.type.ty == Tstruct && (cast(TypeStruct)sd.type).sym != sd)
        {
            auto ti = (cast(TypeStruct)sd.type).sym.isInstantiated();
            if (ti && isError(ti))
                (cast(TypeStruct)sd.type).sym = sd;
        }

        // Ungag errors when not speculative
        Ungag ungag = sd.ungagSpeculative();

        if (sd.semanticRun == PASSinit)
        {
            sd.protection = sc.protection;

            sd.alignment = sc.alignment();

            sd.storage_class |= sc.stc;
            if (sd.storage_class & STCdeprecated)
                sd.isdeprecated = true;
            if (sd.storage_class & STCabstract)
                sd.error("structs, unions cannot be abstract");

            sd.userAttribDecl = sc.userAttribDecl;
        }
        else if (sd.symtab && !scx)
            return;

        sd.semanticRun = PASSsemantic;

        if (!sd.members) // if opaque declaration
        {
            sd.semanticRun = PASSsemanticdone;
            return;
        }
        if (!sd.symtab)
        {
            sd.symtab = new DsymbolTable();

            for (size_t i = 0; i < sd.members.dim; i++)
            {
                auto s = (*sd.members)[i];
                //printf("adding member '%s' to '%s'\n", s.toChars(), this.toChars());
                s.addMember(sc, sd);
            }
        }

        auto sc2 = sd.newScope(sc);

        /* Set scope so if there are forward references, we still might be able to
         * resolve individual members like enums.
         */
        for (size_t i = 0; i < sd.members.dim; i++)
        {
            auto s = (*sd.members)[i];
            //printf("struct: setScope %s %s\n", s.kind(), s.toChars());
            s.setScope(sc2);
        }

        for (size_t i = 0; i < sd.members.dim; i++)
        {
            auto s = (*sd.members)[i];
            s.importAll(sc2);
        }

        for (size_t i = 0; i < sd.members.dim; i++)
        {
            auto s = (*sd.members)[i];
            s.semantic(sc2);
            sd.errors |= s.errors;
        }
        if (sd.errors)
            sd.type = Type.terror;

        if (!sd.determineFields())
        {
            if (sd.type.ty != Terror)
            {
                sd.error(sd.loc, "circular or forward reference");
                sd.errors = true;
                sd.type = Type.terror;
            }

            sc2.pop();
            sd.semanticRun = PASSsemanticdone;
            return;
        }
        /* Following special member functions creation needs semantic analysis
         * completion of sub-structs in each field types. For example, buildDtor
         * needs to check existence of elaborate dtor in type of each fields.
         * See the case in compilable/test14838.d
         */
        foreach (v; sd.fields)
        {
            Type tb = v.type.baseElemOf();
            if (tb.ty != Tstruct)
                continue;
            auto sdec = (cast(TypeStruct)tb).sym;
            if (sdec.semanticRun >= PASSsemanticdone)
                continue;

            sc2.pop();

            sd._scope = scx ? scx : sc.copy();
            sd._scope.setNoFree();
            sd._scope._module.addDeferredSemantic(sd);
            //printf("\tdeferring %s\n", toChars());
            return;
        }

        /* Look for special member functions.
         */
        sd.aggNew = cast(NewDeclaration)sd.search(Loc(), Id.classNew);
        sd.aggDelete = cast(DeleteDeclaration)sd.search(Loc(), Id.classDelete);

        // Look for the constructor
        sd.ctor = sd.searchCtor();

        sd.dtor = buildDtor(sd, sc2);
        sd.postblit = buildPostBlit(sd, sc2);

        buildOpAssign(sd, sc2);
        buildOpEquals(sd, sc2);

        sd.xeq = buildXopEquals(sd, sc2);
        sd.xcmp = buildXopCmp(sd, sc2);
        sd.xhash = buildXtoHash(sd, sc2);

        sd.inv = buildInv(sd, sc2);

        Module.dprogress++;
        sd.semanticRun = PASSsemanticdone;
        //printf("-StructDeclaration::semantic(this=%p, '%s')\n", this, toChars());

        sc2.pop();

        if (sd.ctor)
        {
            Dsymbol scall = sd.search(Loc(), Id.call);
            if (scall)
            {
                uint xerrors = global.startGagging();
                sc = sc.push();
                sc.tinst = null;
                sc.minst = null;
                auto fcall = resolveFuncCall(sd.loc, sc, scall, null, null, null, 1);
                sc = sc.pop();
                global.endGagging(xerrors);

                if (fcall && fcall.isStatic())
                {
                    sd.error(fcall.loc, "static opCall is hidden by constructors and can never be called");
                    errorSupplemental(fcall.loc, "Please use a factory method instead, or replace all constructors with static opCall.");
                }
            }
        }

        if (global.errors != errors)
        {
            // The type is no good.
            sd.type = Type.terror;
            sd.errors = true;
            if (sd.deferred)
                sd.deferred.errors = true;
        }

        if (sd.deferred && !global.gag)
        {
            sd.deferred.semantic2(sc);
            sd.deferred.semantic3(sc);
        }

        version (none)
        {
            if (sd.type.ty == Tstruct && (cast(TypeStruct)sd.type).sym != sd)
            {
                printf("this = %p %s\n", sd, sd.toChars());
                printf("type = %d sym = %p\n", sd.type.ty, (cast(TypeStruct)sd.type).sym);
            }
        }
        assert(sd.type.ty != Tstruct || (cast(TypeStruct)sd.type).sym == sd);
    }

    final void interfaceSemantic(ClassDeclaration cd)
    {
        cd.vtblInterfaces = new BaseClasses();
        cd.vtblInterfaces.reserve(cd.interfaces.length);
        foreach (b; cd.interfaces)
        {
            cd.vtblInterfaces.push(b);
            b.copyBaseInterfaces(cd.vtblInterfaces);
        }
    }

    override void visit(ClassDeclaration cldec)
    {
        //printf("ClassDeclaration.semantic(%s), type = %p, sizeok = %d, this = %p\n", toChars(), type, sizeok, this);
        //printf("\tparent = %p, '%s'\n", sc.parent, sc.parent ? sc.parent.toChars() : "");
        //printf("sc.stc = %x\n", sc.stc);

        //{ static int n;  if (++n == 20) *(char*)0=0; }

        if (cldec.semanticRun >= PASSsemanticdone)
            return;
        int errors = global.errors;

        //printf("+ClassDeclaration.semantic(%s), type = %p, sizeok = %d, this = %p\n", toChars(), type, sizeok, this);

        Scope* scx = null;
        if (cldec._scope)
        {
            sc = cldec._scope;
            scx = cldec._scope; // save so we don't make redundant copies
            cldec._scope = null;
        }

        if (!cldec.parent)
        {
            assert(sc.parent);
            cldec.parent = sc.parent;
        }

        if (cldec.errors)
            cldec.type = Type.terror;
        cldec.type = cldec.type.typeSemantic(cldec.loc, sc);
        if (cldec.type.ty == Tclass && (cast(TypeClass)cldec.type).sym != cldec)
        {
            auto ti = (cast(TypeClass)cldec.type).sym.isInstantiated();
            if (ti && isError(ti))
                (cast(TypeClass)cldec.type).sym = cldec;
        }

        // Ungag errors when not speculative
        Ungag ungag = cldec.ungagSpeculative();

        if (cldec.semanticRun == PASSinit)
        {
            cldec.protection = sc.protection;

            cldec.storage_class |= sc.stc;
            if (cldec.storage_class & STCdeprecated)
                cldec.isdeprecated = true;
            if (cldec.storage_class & STCauto)
                cldec.error("storage class 'auto' is invalid when declaring a class, did you mean to use 'scope'?");
            if (cldec.storage_class & STCscope)
                cldec.isscope = true;
            if (cldec.storage_class & STCabstract)
                cldec.isabstract = ABSyes;

            cldec.userAttribDecl = sc.userAttribDecl;

            if (sc.linkage == LINKcpp)
                cldec.cpp = true;
            if (sc.linkage == LINKobjc)
                objc.setObjc(cldec);
        }
        else if (cldec.symtab && !scx)
        {
            cldec.semanticRun = PASSsemanticdone;
            return;
        }
        cldec.semanticRun = PASSsemantic;

        if (cldec.baseok < BASEOKdone)
        {
            /* https://issues.dlang.org/show_bug.cgi?id=12078
             * https://issues.dlang.org/show_bug.cgi?id=12143
             * https://issues.dlang.org/show_bug.cgi?id=15733
             * While resolving base classes and interfaces, a base may refer
             * the member of this derived class. In that time, if all bases of
             * this class can  be determined, we can go forward the semantc process
             * beyond the Lancestorsdone. To do the recursive semantic analysis,
             * temporarily set and unset `_scope` around exp().
             */
            T resolveBase(T)(lazy T exp)
            {
                if (!scx)
                {
                    scx = sc.copy();
                    scx.setNoFree();
                }
                static if (!is(T == void))
                {
                    cldec._scope = scx;
                    auto r = exp();
                    cldec._scope = null;
                    return r;
                }
                else
                {
                    cldec._scope = scx;
                    exp();
                    cldec._scope = null;
                }
            }

            cldec.baseok = BASEOKin;

            // Expand any tuples in baseclasses[]
            for (size_t i = 0; i < cldec.baseclasses.dim;)
            {
                auto b = (*cldec.baseclasses)[i];
                b.type = resolveBase(b.type.typeSemantic(cldec.loc, sc));

                Type tb = b.type.toBasetype();
                if (tb.ty == Ttuple)
                {
                    TypeTuple tup = cast(TypeTuple)tb;
                    cldec.baseclasses.remove(i);
                    size_t dim = Parameter.dim(tup.arguments);
                    for (size_t j = 0; j < dim; j++)
                    {
                        Parameter arg = Parameter.getNth(tup.arguments, j);
                        b = new BaseClass(arg.type);
                        cldec.baseclasses.insert(i + j, b);
                    }
                }
                else
                    i++;
            }

            if (cldec.baseok >= BASEOKdone)
            {
                //printf("%s already semantic analyzed, semanticRun = %d\n", toChars(), semanticRun);
                if (cldec.semanticRun >= PASSsemanticdone)
                    return;
                goto Lancestorsdone;
            }

            // See if there's a base class as first in baseclasses[]
            if (cldec.baseclasses.dim)
            {
                BaseClass* b = (*cldec.baseclasses)[0];
                Type tb = b.type.toBasetype();
                TypeClass tc = (tb.ty == Tclass) ? cast(TypeClass)tb : null;
                if (!tc)
                {
                    if (b.type != Type.terror)
                        cldec.error("base type must be class or interface, not %s", b.type.toChars());
                    cldec.baseclasses.remove(0);
                    goto L7;
                }
                if (tc.sym.isDeprecated())
                {
                    if (!cldec.isDeprecated())
                    {
                        // Deriving from deprecated class makes this one deprecated too
                        cldec.isdeprecated = true;
                        tc.checkDeprecated(cldec.loc, sc);
                    }
                }
                if (tc.sym.isInterfaceDeclaration())
                    goto L7;

                for (ClassDeclaration cdb = tc.sym; cdb; cdb = cdb.baseClass)
                {
                    if (cdb == cldec)
                    {
                        cldec.error("circular inheritance");
                        cldec.baseclasses.remove(0);
                        goto L7;
                    }
                }

                /* https://issues.dlang.org/show_bug.cgi?id=11034
                 * Class inheritance hierarchy
                 * and instance size of each classes are orthogonal information.
                 * Therefore, even if tc.sym.sizeof == SIZEOKnone,
                 * we need to set baseClass field for class covariance check.
                 */
                cldec.baseClass = tc.sym;
                b.sym = cldec.baseClass;

                if (tc.sym.baseok < BASEOKdone)
                    resolveBase(tc.sym.semantic(null)); // Try to resolve forward reference
                if (tc.sym.baseok < BASEOKdone)
                {
                    //printf("\ttry later, forward reference of base class %s\n", tc.sym.toChars());
                    if (tc.sym._scope)
                        tc.sym._scope._module.addDeferredSemantic(tc.sym);
                    cldec.baseok = BASEOKnone;
                }
            L7:
            }

            // Treat the remaining entries in baseclasses as interfaces
            // Check for errors, handle forward references
            for (size_t i = (cldec.baseClass ? 1 : 0); i < cldec.baseclasses.dim;)
            {
                BaseClass* b = (*cldec.baseclasses)[i];
                Type tb = b.type.toBasetype();
                TypeClass tc = (tb.ty == Tclass) ? cast(TypeClass)tb : null;
                if (!tc || !tc.sym.isInterfaceDeclaration())
                {
                    if (b.type != Type.terror)
                        cldec.error("base type must be interface, not %s", b.type.toChars());
                    cldec.baseclasses.remove(i);
                    continue;
                }

                // Check for duplicate interfaces
                for (size_t j = (cldec.baseClass ? 1 : 0); j < i; j++)
                {
                    BaseClass* b2 = (*cldec.baseclasses)[j];
                    if (b2.sym == tc.sym)
                    {
                        cldec.error("inherits from duplicate interface %s", b2.sym.toChars());
                        cldec.baseclasses.remove(i);
                        continue;
                    }
                }
                if (tc.sym.isDeprecated())
                {
                    if (!cldec.isDeprecated())
                    {
                        // Deriving from deprecated class makes this one deprecated too
                        cldec.isdeprecated = true;
                        tc.checkDeprecated(cldec.loc, sc);
                    }
                }

                b.sym = tc.sym;

                if (tc.sym.baseok < BASEOKdone)
                    resolveBase(tc.sym.semantic(null)); // Try to resolve forward reference
                if (tc.sym.baseok < BASEOKdone)
                {
                    //printf("\ttry later, forward reference of base %s\n", tc.sym.toChars());
                    if (tc.sym._scope)
                        tc.sym._scope._module.addDeferredSemantic(tc.sym);
                    cldec.baseok = BASEOKnone;
                }
                i++;
            }
            if (cldec.baseok == BASEOKnone)
            {
                // Forward referencee of one or more bases, try again later
                cldec._scope = scx ? scx : sc.copy();
                cldec._scope.setNoFree();
                cldec._scope._module.addDeferredSemantic(cldec);
                //printf("\tL%d semantic('%s') failed due to forward references\n", __LINE__, toChars());
                return;
            }
            cldec.baseok = BASEOKdone;

            // If no base class, and this is not an Object, use Object as base class
            if (!cldec.baseClass && cldec.ident != Id.Object && !cldec.cpp)
            {
                void badObjectDotD()
                {
                    cldec.error("missing or corrupt object.d");
                    fatal();
                }

                if (!cldec.object || cldec.object.errors)
                    badObjectDotD();

                Type t = cldec.object.type;
                t = t.typeSemantic(cldec.loc, sc).toBasetype();
                if (t.ty == Terror)
                    badObjectDotD();
                assert(t.ty == Tclass);
                TypeClass tc = cast(TypeClass)t;

                auto b = new BaseClass(tc);
                cldec.baseclasses.shift(b);

                cldec.baseClass = tc.sym;
                assert(!cldec.baseClass.isInterfaceDeclaration());
                b.sym = cldec.baseClass;
            }
            if (cldec.baseClass)
            {
                if (cldec.baseClass.storage_class & STCfinal)
                    cldec.error("cannot inherit from final class %s", cldec.baseClass.toChars());

                // Inherit properties from base class
                if (cldec.baseClass.isCOMclass())
                    cldec.com = true;
                if (cldec.baseClass.isCPPclass())
                    cldec.cpp = true;
                if (cldec.baseClass.isscope)
                    cldec.isscope = true;
                cldec.enclosing = cldec.baseClass.enclosing;
                cldec.storage_class |= cldec.baseClass.storage_class & STC_TYPECTOR;
            }

            cldec.interfaces = cldec.baseclasses.tdata()[(cldec.baseClass ? 1 : 0) .. cldec.baseclasses.dim];
            foreach (b; cldec.interfaces)
            {
                // If this is an interface, and it derives from a COM interface,
                // then this is a COM interface too.
                if (b.sym.isCOMinterface())
                    cldec.com = true;
                if (cldec.cpp && !b.sym.isCPPinterface())
                {
                    error(cldec.loc, "C++ class '%s' cannot implement D interface '%s'",
                        cldec.toPrettyChars(), b.sym.toPrettyChars());
                }
            }
            interfaceSemantic(cldec);
        }
    Lancestorsdone:
        //printf("\tClassDeclaration.semantic(%s) baseok = %d\n", toChars(), baseok);

        if (!cldec.members) // if opaque declaration
        {
            cldec.semanticRun = PASSsemanticdone;
            return;
        }
        if (!cldec.symtab)
        {
            cldec.symtab = new DsymbolTable();

            /* https://issues.dlang.org/show_bug.cgi?id=12152
             * The semantic analysis of base classes should be finished
             * before the members semantic analysis of this class, in order to determine
             * vtbl in this class. However if a base class refers the member of this class,
             * it can be resolved as a normal forward reference.
             * Call addMember() and setScope() to make this class members visible from the base classes.
             */
            for (size_t i = 0; i < cldec.members.dim; i++)
            {
                auto s = (*cldec.members)[i];
                s.addMember(sc, cldec);
            }

            auto sc2 = cldec.newScope(sc);

            /* Set scope so if there are forward references, we still might be able to
             * resolve individual members like enums.
             */
            for (size_t i = 0; i < cldec.members.dim; i++)
            {
                auto s = (*cldec.members)[i];
                //printf("[%d] setScope %s %s, sc2 = %p\n", i, s.kind(), s.toChars(), sc2);
                s.setScope(sc2);
            }

            sc2.pop();
        }

        for (size_t i = 0; i < cldec.baseclasses.dim; i++)
        {
            BaseClass* b = (*cldec.baseclasses)[i];
            Type tb = b.type.toBasetype();
            assert(tb.ty == Tclass);
            TypeClass tc = cast(TypeClass)tb;
            if (tc.sym.semanticRun < PASSsemanticdone)
            {
                // Forward referencee of one or more bases, try again later
                cldec._scope = scx ? scx : sc.copy();
                cldec._scope.setNoFree();
                if (tc.sym._scope)
                    tc.sym._scope._module.addDeferredSemantic(tc.sym);
                cldec._scope._module.addDeferredSemantic(cldec);
                //printf("\tL%d semantic('%s') failed due to forward references\n", __LINE__, toChars());
                return;
            }
        }

        if (cldec.baseok == BASEOKdone)
        {
            cldec.baseok = BASEOKsemanticdone;

            // initialize vtbl
            if (cldec.baseClass)
            {
                if (cldec.cpp && cldec.baseClass.vtbl.dim == 0)
                {
                    cldec.error("C++ base class %s needs at least one virtual function", cldec.baseClass.toChars());
                }

                // Copy vtbl[] from base class
                cldec.vtbl.setDim(cldec.baseClass.vtbl.dim);
                memcpy(cldec.vtbl.tdata(), cldec.baseClass.vtbl.tdata(), (void*).sizeof * cldec.vtbl.dim);

                cldec.vthis = cldec.baseClass.vthis;
            }
            else
            {
                // No base class, so this is the root of the class hierarchy
                cldec.vtbl.setDim(0);
                if (cldec.vtblOffset())
                    cldec.vtbl.push(cldec); // leave room for classinfo as first member
            }

            /* If this is a nested class, add the hidden 'this'
             * member which is a pointer to the enclosing scope.
             */
            if (cldec.vthis) // if inheriting from nested class
            {
                // Use the base class's 'this' member
                if (cldec.storage_class & STCstatic)
                    cldec.error("static class cannot inherit from nested class %s", cldec.baseClass.toChars());
                if (cldec.toParent2() != cldec.baseClass.toParent2() &&
                    (!cldec.toParent2() ||
                     !cldec.baseClass.toParent2().getType() ||
                     !cldec.baseClass.toParent2().getType().isBaseOf(cldec.toParent2().getType(), null)))
                {
                    if (cldec.toParent2())
                    {
                        cldec.error("is nested within %s, but super class %s is nested within %s",
                            cldec.toParent2().toChars(),
                            cldec.baseClass.toChars(),
                            cldec.baseClass.toParent2().toChars());
                    }
                    else
                    {
                        cldec.error("is not nested, but super class %s is nested within %s",
                            cldec.baseClass.toChars(),
                            cldec.baseClass.toParent2().toChars());
                    }
                    cldec.enclosing = null;
                }
            }
            else
                cldec.makeNested();
        }

        auto sc2 = cldec.newScope(sc);

        for (size_t i = 0; i < cldec.members.dim; ++i)
        {
            auto s = (*cldec.members)[i];
            s.importAll(sc2);
        }

        // Note that members.dim can grow due to tuple expansion during semantic()
        for (size_t i = 0; i < cldec.members.dim; ++i)
        {
            auto s = (*cldec.members)[i];
            s.semantic(sc2);
        }

        if (!cldec.determineFields())
        {
            assert(cldec.type == Type.terror);
            sc2.pop();
            return;
        }
        /* Following special member functions creation needs semantic analysis
         * completion of sub-structs in each field types.
         */
        foreach (v; cldec.fields)
        {
            Type tb = v.type.baseElemOf();
            if (tb.ty != Tstruct)
                continue;
            auto sd = (cast(TypeStruct)tb).sym;
            if (sd.semanticRun >= PASSsemanticdone)
                continue;

            sc2.pop();

            cldec._scope = scx ? scx : sc.copy();
            cldec._scope.setNoFree();
            cldec._scope._module.addDeferredSemantic(cldec);
            //printf("\tdeferring %s\n", toChars());
            return;
        }

        /* Look for special member functions.
         * They must be in this class, not in a base class.
         */
        // Can be in base class
        cldec.aggNew = cast(NewDeclaration)cldec.search(Loc(), Id.classNew);
        cldec.aggDelete = cast(DeleteDeclaration)cldec.search(Loc(), Id.classDelete);

        // Look for the constructor
        cldec.ctor = cldec.searchCtor();

        if (!cldec.ctor && cldec.noDefaultCtor)
        {
            // A class object is always created by constructor, so this check is legitimate.
            foreach (v; cldec.fields)
            {
                if (v.storage_class & STCnodefaultctor)
                    error(v.loc, "field %s must be initialized in constructor", v.toChars());
            }
        }

        // If this class has no constructor, but base class has a default
        // ctor, create a constructor:
        //    this() { }
        if (!cldec.ctor && cldec.baseClass && cldec.baseClass.ctor)
        {
            auto fd = resolveFuncCall(cldec.loc, sc2, cldec.baseClass.ctor, null, cldec.type, null, 1);
            if (!fd) // try shared base ctor instead
                fd = resolveFuncCall(cldec.loc, sc2, cldec.baseClass.ctor, null, cldec.type.sharedOf, null, 1);
            if (fd && !fd.errors)
            {
                //printf("Creating default this(){} for class %s\n", toChars());
                auto btf = fd.type.toTypeFunction();
                auto tf = new TypeFunction(null, null, 0, LINKd, fd.storage_class);
                tf.mod       = btf.mod;
                tf.purity    = btf.purity;
                tf.isnothrow = btf.isnothrow;
                tf.isnogc    = btf.isnogc;
                tf.trust     = btf.trust;

                auto ctor = new CtorDeclaration(cldec.loc, Loc(), 0, tf);
                ctor.fbody = new CompoundStatement(Loc(), new Statements());

                cldec.members.push(ctor);
                ctor.addMember(sc, cldec);
                ctor.semantic(sc2);

                cldec.ctor = ctor;
                cldec.defaultCtor = ctor;
            }
            else
            {
                cldec.error("cannot implicitly generate a default ctor when base class %s is missing a default ctor",
                    cldec.baseClass.toPrettyChars());
            }
        }

        cldec.dtor = buildDtor(cldec, sc2);

        if (auto f = hasIdentityOpAssign(cldec, sc2))
        {
            if (!(f.storage_class & STCdisable))
                cldec.error(f.loc, "identity assignment operator overload is illegal");
        }

        cldec.inv = buildInv(cldec, sc2);

        Module.dprogress++;
        cldec.semanticRun = PASSsemanticdone;
        //printf("-ClassDeclaration.semantic(%s), type = %p\n", toChars(), type);
        //members.print();

        sc2.pop();

        /* isAbstract() is undecidable in some cases because of circular dependencies.
         * Now that semantic is finished, get a definitive result, and error if it is not the same.
         */
        if (cldec.isabstract != ABSfwdref)    // if evaluated it before completion
        {
            const isabstractsave = cldec.isabstract;
            cldec.isabstract = ABSfwdref;
            cldec.isAbstract();               // recalculate
            if (cldec.isabstract != isabstractsave)
            {
                cldec.error("cannot infer `abstract` attribute due to circular dependencies");
            }
        }

        if (cldec.type.ty == Tclass && (cast(TypeClass)cldec.type).sym != cldec)
        {
            // https://issues.dlang.org/show_bug.cgi?id=17492
            ClassDeclaration cd = (cast(TypeClass)cldec.type).sym;
            version (none)
            {
                printf("this = %p %s\n", cldec, cldec.toPrettyChars());
                printf("type = %d sym = %p, %s\n", cldec.type.ty, cd, cd.toPrettyChars());
            }
            cldec.error("already exists at %s. Perhaps in another function with the same name?", cd.loc.toChars());
        }

        if (global.errors != errors)
        {
            // The type is no good.
            cldec.type = Type.terror;
            cldec.errors = true;
            if (cldec.deferred)
                cldec.deferred.errors = true;
        }

        // Verify fields of a synchronized class are not public
        if (cldec.storage_class & STCsynchronized)
        {
            foreach (vd; cldec.fields)
            {
                if (!vd.isThisDeclaration() &&
                    !vd.prot().isMoreRestrictiveThan(Prot(PROTpublic)))
                {
                    vd.error("Field members of a synchronized class cannot be %s",
                        protectionToChars(vd.prot().kind));
                }
            }
        }

        if (cldec.deferred && !global.gag)
        {
            cldec.deferred.semantic2(sc);
            cldec.deferred.semantic3(sc);
        }
        //printf("-ClassDeclaration.semantic(%s), type = %p, sizeok = %d, this = %p\n", toChars(), type, sizeok, this);
    }

    override void visit(InterfaceDeclaration idec)
    {
        //printf("InterfaceDeclaration.semantic(%s), type = %p\n", toChars(), type);
        if (idec.semanticRun >= PASSsemanticdone)
            return;
        int errors = global.errors;

        //printf("+InterfaceDeclaration.semantic(%s), type = %p\n", toChars(), type);

        Scope* scx = null;
        if (idec._scope)
        {
            sc = idec._scope;
            scx = idec._scope; // save so we don't make redundant copies
            idec._scope = null;
        }

        if (!idec.parent)
        {
            assert(sc.parent && sc.func);
            idec.parent = sc.parent;
        }
        assert(idec.parent && !idec.isAnonymous());

        if (idec.errors)
            idec.type = Type.terror;
        idec.type = idec.type.typeSemantic(idec.loc, sc);
        if (idec.type.ty == Tclass && (cast(TypeClass)idec.type).sym != idec)
        {
            auto ti = (cast(TypeClass)idec.type).sym.isInstantiated();
            if (ti && isError(ti))
                (cast(TypeClass)idec.type).sym = idec;
        }

        // Ungag errors when not speculative
        Ungag ungag = idec.ungagSpeculative();

        if (idec.semanticRun == PASSinit)
        {
            idec.protection = sc.protection;

            idec.storage_class |= sc.stc;
            if (idec.storage_class & STCdeprecated)
                idec.isdeprecated = true;

            idec.userAttribDecl = sc.userAttribDecl;
        }
        else if (idec.symtab)
        {
            if (idec.sizeok == SIZEOKdone || !scx)
            {
                idec.semanticRun = PASSsemanticdone;
                return;
            }
        }
        idec.semanticRun = PASSsemantic;

        if (idec.baseok < BASEOKdone)
        {
            T resolveBase(T)(lazy T exp)
            {
                if (!scx)
                {
                    scx = sc.copy();
                    scx.setNoFree();
                }
                static if (!is(T == void))
                {
                    idec._scope = scx;
                    auto r = exp();
                    idec._scope = null;
                    return r;
                }
                else
                {
                    idec._scope = scx;
                    exp();
                    idec._scope = null;
                }
            }

            idec.baseok = BASEOKin;

            // Expand any tuples in baseclasses[]
            for (size_t i = 0; i < idec.baseclasses.dim;)
            {
                auto b = (*idec.baseclasses)[i];
                b.type = resolveBase(b.type.typeSemantic(idec.loc, sc));

                Type tb = b.type.toBasetype();
                if (tb.ty == Ttuple)
                {
                    TypeTuple tup = cast(TypeTuple)tb;
                    idec.baseclasses.remove(i);
                    size_t dim = Parameter.dim(tup.arguments);
                    for (size_t j = 0; j < dim; j++)
                    {
                        Parameter arg = Parameter.getNth(tup.arguments, j);
                        b = new BaseClass(arg.type);
                        idec.baseclasses.insert(i + j, b);
                    }
                }
                else
                    i++;
            }

            if (idec.baseok >= BASEOKdone)
            {
                //printf("%s already semantic analyzed, semanticRun = %d\n", toChars(), semanticRun);
                if (idec.semanticRun >= PASSsemanticdone)
                    return;
                goto Lancestorsdone;
            }

            if (!idec.baseclasses.dim && sc.linkage == LINKcpp)
                idec.cpp = true;

            if (sc.linkage == LINKobjc)
                objc.setObjc(idec);

            // Check for errors, handle forward references
            for (size_t i = 0; i < idec.baseclasses.dim;)
            {
                BaseClass* b = (*idec.baseclasses)[i];
                Type tb = b.type.toBasetype();
                TypeClass tc = (tb.ty == Tclass) ? cast(TypeClass)tb : null;
                if (!tc || !tc.sym.isInterfaceDeclaration())
                {
                    if (b.type != Type.terror)
                        idec.error("base type must be interface, not %s", b.type.toChars());
                    idec.baseclasses.remove(i);
                    continue;
                }

                // Check for duplicate interfaces
                for (size_t j = 0; j < i; j++)
                {
                    BaseClass* b2 = (*idec.baseclasses)[j];
                    if (b2.sym == tc.sym)
                    {
                        idec.error("inherits from duplicate interface %s", b2.sym.toChars());
                        idec.baseclasses.remove(i);
                        continue;
                    }
                }
                if (tc.sym == idec || idec.isBaseOf2(tc.sym))
                {
                    idec.error("circular inheritance of interface");
                    idec.baseclasses.remove(i);
                    continue;
                }
                if (tc.sym.isDeprecated())
                {
                    if (!idec.isDeprecated())
                    {
                        // Deriving from deprecated class makes this one deprecated too
                        idec.isdeprecated = true;
                        tc.checkDeprecated(idec.loc, sc);
                    }
                }

                b.sym = tc.sym;

                if (tc.sym.baseok < BASEOKdone)
                    resolveBase(tc.sym.semantic(null)); // Try to resolve forward reference
                if (tc.sym.baseok < BASEOKdone)
                {
                    //printf("\ttry later, forward reference of base %s\n", tc.sym.toChars());
                    if (tc.sym._scope)
                        tc.sym._scope._module.addDeferredSemantic(tc.sym);
                    idec.baseok = BASEOKnone;
                }
                i++;
            }
            if (idec.baseok == BASEOKnone)
            {
                // Forward referencee of one or more bases, try again later
                idec._scope = scx ? scx : sc.copy();
                idec._scope.setNoFree();
                idec._scope._module.addDeferredSemantic(idec);
                return;
            }
            idec.baseok = BASEOKdone;

            idec.interfaces = idec.baseclasses.tdata()[0 .. idec.baseclasses.dim];
            foreach (b; idec.interfaces)
            {
                // If this is an interface, and it derives from a COM interface,
                // then this is a COM interface too.
                if (b.sym.isCOMinterface())
                    idec.com = true;
                if (b.sym.isCPPinterface())
                    idec.cpp = true;
            }

            interfaceSemantic(idec);
        }
    Lancestorsdone:

        if (!idec.members) // if opaque declaration
        {
            idec.semanticRun = PASSsemanticdone;
            return;
        }
        if (!idec.symtab)
            idec.symtab = new DsymbolTable();

        for (size_t i = 0; i < idec.baseclasses.dim; i++)
        {
            BaseClass* b = (*idec.baseclasses)[i];
            Type tb = b.type.toBasetype();
            assert(tb.ty == Tclass);
            TypeClass tc = cast(TypeClass)tb;
            if (tc.sym.semanticRun < PASSsemanticdone)
            {
                // Forward referencee of one or more bases, try again later
                idec._scope = scx ? scx : sc.copy();
                idec._scope.setNoFree();
                if (tc.sym._scope)
                    tc.sym._scope._module.addDeferredSemantic(tc.sym);
                idec._scope._module.addDeferredSemantic(idec);
                return;
            }
        }

        if (idec.baseok == BASEOKdone)
        {
            idec.baseok = BASEOKsemanticdone;

            // initialize vtbl
            if (idec.vtblOffset())
                idec.vtbl.push(idec); // leave room at vtbl[0] for classinfo

            // Cat together the vtbl[]'s from base interfaces
            foreach (i, b; idec.interfaces)
            {
                // Skip if b has already appeared
                for (size_t k = 0; k < i; k++)
                {
                    if (b == idec.interfaces[k])
                        goto Lcontinue;
                }

                // Copy vtbl[] from base class
                if (b.sym.vtblOffset())
                {
                    size_t d = b.sym.vtbl.dim;
                    if (d > 1)
                    {
                        idec.vtbl.reserve(d - 1);
                        for (size_t j = 1; j < d; j++)
                            idec.vtbl.push(b.sym.vtbl[j]);
                    }
                }
                else
                {
                    idec.vtbl.append(&b.sym.vtbl);
                }

            Lcontinue:
            }
        }

        for (size_t i = 0; i < idec.members.dim; i++)
        {
            Dsymbol s = (*idec.members)[i];
            s.addMember(sc, idec);
        }

        auto sc2 = idec.newScope(sc);

        /* Set scope so if there are forward references, we still might be able to
         * resolve individual members like enums.
         */
        for (size_t i = 0; i < idec.members.dim; i++)
        {
            Dsymbol s = (*idec.members)[i];
            //printf("setScope %s %s\n", s.kind(), s.toChars());
            s.setScope(sc2);
        }

        for (size_t i = 0; i < idec.members.dim; i++)
        {
            Dsymbol s = (*idec.members)[i];
            s.importAll(sc2);
        }

        for (size_t i = 0; i < idec.members.dim; i++)
        {
            Dsymbol s = (*idec.members)[i];
            s.semantic(sc2);
        }

        Module.dprogress++;
        idec.semanticRun = PASSsemanticdone;
        //printf("-InterfaceDeclaration.semantic(%s), type = %p\n", toChars(), type);
        //members.print();

        sc2.pop();

        if (global.errors != errors)
        {
            // The type is no good.
            idec.type = Type.terror;
        }

        version (none)
        {
            if (type.ty == Tclass && (cast(TypeClass)idec.type).sym != idec)
            {
                printf("this = %p %s\n", idec, idec.toChars());
                printf("type = %d sym = %p\n", idec.type.ty, (cast(TypeClass)idec.type).sym);
            }
        }
        assert(idec.type.ty != Tclass || (cast(TypeClass)idec.type).sym == idec);
    }
}

void templateInstanceSemantic(TemplateInstance tempinst, Scope* sc, Expressions* fargs)
{
    //printf("[%s] TemplateInstance.semantic('%s', this=%p, gag = %d, sc = %p)\n", loc.toChars(), toChars(), this, global.gag, sc);
    version (none)
    {
        for (Dsymbol s = tempinst; s; s = s.parent)
        {
            printf("\t%s\n", s.toChars());
        }
        printf("Scope\n");
        for (Scope* scx = sc; scx; scx = scx.enclosing)
        {
            printf("\t%s parent %s\n", scx._module ? scx._module.toChars() : "null", scx.parent ? scx.parent.toChars() : "null");
        }
    }

    static if (LOG)
    {
        printf("\n+TemplateInstance.semantic('%s', this=%p)\n", tempinst.toChars(), tempinst);
    }
    if (tempinst.inst) // if semantic() was already run
    {
        static if (LOG)
        {
            printf("-TemplateInstance.semantic('%s', this=%p) already run\n", inst.toChars(), tempinst.inst);
        }
        return;
    }
    if (tempinst.semanticRun != PASSinit)
    {
        static if (LOG)
        {
            printf("Recursive template expansion\n");
        }
        auto ungag = Ungag(global.gag);
        if (!tempinst.gagged)
            global.gag = 0;
        tempinst.error(tempinst.loc, "recursive template expansion");
        if (tempinst.gagged)
            tempinst.semanticRun = PASSinit;
        else
            tempinst.inst = tempinst;
        tempinst.errors = true;
        return;
    }

    // Get the enclosing template instance from the scope tinst
    tempinst.tinst = sc.tinst;

    // Get the instantiating module from the scope minst
    tempinst.minst = sc.minst;
    // https://issues.dlang.org/show_bug.cgi?id=10920
    // If the enclosing function is non-root symbol,
    // this instance should be speculative.
    if (!tempinst.tinst && sc.func && sc.func.inNonRoot())
    {
        tempinst.minst = null;
    }

    tempinst.gagged = (global.gag > 0);

    tempinst.semanticRun = PASSsemantic;

    static if (LOG)
    {
        printf("\tdo semantic\n");
    }
    /* Find template declaration first,
     * then run semantic on each argument (place results in tiargs[]),
     * last find most specialized template from overload list/set.
     */
    if (!tempinst.findTempDecl(sc, null) || !tempinst.semanticTiargs(sc) || !tempinst.findBestMatch(sc, fargs))
    {
    Lerror:
        if (tempinst.gagged)
        {
            // https://issues.dlang.org/show_bug.cgi?id=13220
            // Roll back status for later semantic re-running
            tempinst.semanticRun = PASSinit;
        }
        else
            tempinst.inst = tempinst;
        tempinst.errors = true;
        return;
    }
    TemplateDeclaration tempdecl = tempinst.tempdecl.isTemplateDeclaration();
    assert(tempdecl);

    // If tempdecl is a mixin, disallow it
    if (tempdecl.ismixin)
    {
        tempinst.error("mixin templates are not regular templates");
        goto Lerror;
    }

    tempinst.hasNestedArgs(tempinst.tiargs, tempdecl.isstatic);
    if (tempinst.errors)
        goto Lerror;

    /* See if there is an existing TemplateInstantiation that already
     * implements the typeargs. If so, just refer to that one instead.
     */
    tempinst.inst = tempdecl.findExistingInstance(tempinst, fargs);
    TemplateInstance errinst = null;
    if (!tempinst.inst)
    {
        // So, we need to implement 'this' instance.
    }
    else if (tempinst.inst.gagged && !tempinst.gagged && tempinst.inst.errors)
    {
        // If the first instantiation had failed, re-run semantic,
        // so that error messages are shown.
        errinst = tempinst.inst;
    }
    else
    {
        // It's a match
        tempinst.parent = tempinst.inst.parent;
        tempinst.errors = tempinst.inst.errors;

        // If both this and the previous instantiation were gagged,
        // use the number of errors that happened last time.
        global.errors += tempinst.errors;
        global.gaggedErrors += tempinst.errors;

        // If the first instantiation was gagged, but this is not:
        if (tempinst.inst.gagged)
        {
            // It had succeeded, mark it is a non-gagged instantiation,
            // and reuse it.
            tempinst.inst.gagged = tempinst.gagged;
        }

        tempinst.tnext = tempinst.inst.tnext;
        tempinst.inst.tnext = tempinst;

        /* A module can have explicit template instance and its alias
         * in module scope (e,g, `alias Base64 = Base64Impl!('+', '/');`).
         * If the first instantiation 'inst' had happened in non-root module,
         * compiler can assume that its instantiated code would be included
         * in the separately compiled obj/lib file (e.g. phobos.lib).
         *
         * However, if 'this' second instantiation happened in root module,
         * compiler might need to invoke its codegen
         * (https://issues.dlang.org/show_bug.cgi?id=2500 & https://issues.dlang.org/show_bug.cgi?id=2644).
         * But whole import graph is not determined until all semantic pass finished,
         * so 'inst' should conservatively finish the semantic3 pass for the codegen.
         */
        if (tempinst.minst && tempinst.minst.isRoot() && !(tempinst.inst.minst && tempinst.inst.minst.isRoot()))
        {
            /* Swap the position of 'inst' and 'this' in the instantiation graph.
             * Then, the primary instance `inst` will be changed to a root instance.
             *
             * Before:
             *  non-root -> A!() -> B!()[inst] -> C!()
             *                      |
             *  root     -> D!() -> B!()[this]
             *
             * After:
             *  non-root -> A!() -> B!()[this]
             *                      |
             *  root     -> D!() -> B!()[inst] -> C!()
             */
            Module mi = tempinst.minst;
            TemplateInstance ti = tempinst.tinst;
            tempinst.minst = tempinst.inst.minst;
            tempinst.tinst = tempinst.inst.tinst;
            tempinst.inst.minst = mi;
            tempinst.inst.tinst = ti;

            if (tempinst.minst) // if inst was not speculative
            {
                /* Add 'inst' once again to the root module members[], then the
                 * instance members will get codegen chances.
                 */
                tempinst.inst.appendToModuleMember();
            }
        }
        static if (LOG)
        {
            printf("\tit's a match with instance %p, %d\n", tempinst.inst, tempinst.inst.semanticRun);
        }
        return;
    }
    static if (LOG)
    {
        printf("\timplement template instance %s '%s'\n", tempdecl.parent.toChars(), tempinst.toChars());
        printf("\ttempdecl %s\n", tempdecl.toChars());
    }
    uint errorsave = global.errors;

    tempinst.inst = tempinst;
    tempinst.parent = tempinst.enclosing ? tempinst.enclosing : tempdecl.parent;
    //printf("parent = '%s'\n", parent.kind());

    TemplateInstance tempdecl_instance_idx = tempdecl.addInstance(tempinst);

    //getIdent();

    // Store the place we added it to in target_symbol_list(_idx) so we can
    // remove it later if we encounter an error.
    Dsymbols* target_symbol_list = tempinst.appendToModuleMember();
    size_t target_symbol_list_idx = target_symbol_list ? target_symbol_list.dim - 1 : 0;

    // Copy the syntax trees from the TemplateDeclaration
    tempinst.members = Dsymbol.arraySyntaxCopy(tempdecl.members);

    // resolve TemplateThisParameter
    for (size_t i = 0; i < tempdecl.parameters.dim; i++)
    {
        if ((*tempdecl.parameters)[i].isTemplateThisParameter() is null)
            continue;
        Type t = isType((*tempinst.tiargs)[i]);
        assert(t);
        if (StorageClass stc = ModToStc(t.mod))
        {
            //printf("t = %s, stc = x%llx\n", t.toChars(), stc);
            auto s = new Dsymbols();
            s.push(new StorageClassDeclaration(stc, tempinst.members));
            tempinst.members = s;
        }
        break;
    }

    // Create our own scope for the template parameters
    Scope* _scope = tempdecl._scope;
    if (tempdecl.semanticRun == PASSinit)
    {
        tempinst.error("template instantiation %s forward references template declaration %s", tempinst.toChars(), tempdecl.toChars());
        return;
    }

    static if (LOG)
    {
        printf("\tcreate scope for template parameters '%s'\n", tempinst.toChars());
    }
    tempinst.argsym = new ScopeDsymbol();
    tempinst.argsym.parent = _scope.parent;
    _scope = _scope.push(tempinst.argsym);
    _scope.tinst = tempinst;
    _scope.minst = tempinst.minst;
    //scope.stc = 0;

    // Declare each template parameter as an alias for the argument type
    Scope* paramscope = _scope.push();
    paramscope.stc = 0;
    paramscope.protection = Prot(PROTpublic); // https://issues.dlang.org/show_bug.cgi?id=14169
                                              // template parameters should be public
    tempinst.declareParameters(paramscope);
    paramscope.pop();

    // Add members of template instance to template instance symbol table
    //parent = scope.scopesym;
    tempinst.symtab = new DsymbolTable();
    for (size_t i = 0; i < tempinst.members.dim; i++)
    {
        Dsymbol s = (*tempinst.members)[i];
        static if (LOG)
        {
            printf("\t[%d] adding member '%s' %p kind %s to '%s'\n", i, s.toChars(), s, s.kind(), tempinst.toChars());
        }
        s.addMember(_scope, tempinst);
    }
    static if (LOG)
    {
        printf("adding members done\n");
    }

    /* See if there is only one member of template instance, and that
     * member has the same name as the template instance.
     * If so, this template instance becomes an alias for that member.
     */
    //printf("members.dim = %d\n", members.dim);
    if (tempinst.members.dim)
    {
        Dsymbol s;
        if (Dsymbol.oneMembers(tempinst.members, &s, tempdecl.ident) && s)
        {
            //printf("tempdecl.ident = %s, s = '%s'\n", tempdecl.ident.toChars(), s.kind(), s.toPrettyChars());
            //printf("setting aliasdecl\n");
            tempinst.aliasdecl = s;
            version(IN_LLVM)
            {
                // LDC propagate internal information
                if (tempdecl.llvmInternal != 0) {
                    s.llvmInternal = tempdecl.llvmInternal;
                    if (FuncDeclaration fd = s.isFuncDeclaration()) {
                        DtoSetFuncDeclIntrinsicName(tempinst, tempdecl, fd);
                    }
                }
            }
        }
    }

    /* If function template declaration
     */
    if (fargs && tempinst.aliasdecl)
    {
        FuncDeclaration fd = tempinst.aliasdecl.isFuncDeclaration();
        if (fd)
        {
            /* Transmit fargs to type so that TypeFunction.semantic() can
             * resolve any "auto ref" storage classes.
             */
            TypeFunction tf = cast(TypeFunction)fd.type;
            if (tf && tf.ty == Tfunction)
                tf.fargs = fargs;
        }
    }

    // Do semantic() analysis on template instance members
    static if (LOG)
    {
        printf("\tdo semantic() on template instance members '%s'\n", tempinst.toChars());
    }
    Scope* sc2;
    sc2 = _scope.push(tempinst);
    //printf("enclosing = %d, sc.parent = %s\n", enclosing, sc.parent.toChars());
    sc2.parent = tempinst;
    sc2.tinst = tempinst;
    sc2.minst = tempinst.minst;

    tempinst.tryExpandMembers(sc2);

    tempinst.semanticRun = PASSsemanticdone;

    /* ConditionalDeclaration may introduce eponymous declaration,
     * so we should find it once again after semantic.
     */
    if (tempinst.members.dim)
    {
        Dsymbol s;
        if (Dsymbol.oneMembers(tempinst.members, &s, tempdecl.ident) && s)
        {
            if (!tempinst.aliasdecl || tempinst.aliasdecl != s)
            {
                //printf("tempdecl.ident = %s, s = '%s'\n", tempdecl.ident.toChars(), s.kind(), s.toPrettyChars());
                //printf("setting aliasdecl 2\n");
                tempinst.aliasdecl = s;
            }
        }
    }

    if (global.errors != errorsave)
        goto Laftersemantic;

    /* If any of the instantiation members didn't get semantic() run
     * on them due to forward references, we cannot run semantic2()
     * or semantic3() yet.
     */
    {
        bool found_deferred_ad = false;
        for (size_t i = 0; i < Module.deferred.dim; i++)
        {
            Dsymbol sd = Module.deferred[i];
            AggregateDeclaration ad = sd.isAggregateDeclaration();
            if (ad && ad.parent && ad.parent.isTemplateInstance())
            {
                //printf("deferred template aggregate: %s %s\n",
                //        sd.parent.toChars(), sd.toChars());
                found_deferred_ad = true;
                if (ad.parent == tempinst)
                {
                    ad.deferred = tempinst;
                    break;
                }
            }
        }
        if (found_deferred_ad || Module.deferred.dim)
            goto Laftersemantic;
    }

    /* The problem is when to parse the initializer for a variable.
     * Perhaps VarDeclaration.semantic() should do it like it does
     * for initializers inside a function.
     */
    //if (sc.parent.isFuncDeclaration())
    {
        /* https://issues.dlang.org/show_bug.cgi?id=782
         * this has problems if the classes this depends on
         * are forward referenced. Find a way to defer semantic()
         * on this template.
         */
        tempinst.semantic2(sc2);
    }
    if (global.errors != errorsave)
        goto Laftersemantic;

    if ((sc.func || (sc.flags & SCOPEfullinst)) && !tempinst.tinst)
    {
        /* If a template is instantiated inside function, the whole instantiation
         * should be done at that position. But, immediate running semantic3 of
         * dependent templates may cause unresolved forward reference.
         * https://issues.dlang.org/show_bug.cgi?id=9050
         * To avoid the issue, don't run semantic3 until semantic and semantic2 done.
         */
        TemplateInstances deferred;
        tempinst.deferred = &deferred;

        //printf("Run semantic3 on %s\n", toChars());
        tempinst.trySemantic3(sc2);

        for (size_t i = 0; i < deferred.dim; i++)
        {
            //printf("+ run deferred semantic3 on %s\n", deferred[i].toChars());
            deferred[i].semantic3(null);
        }

        tempinst.deferred = null;
    }
    else if (tempinst.tinst)
    {
        bool doSemantic3 = false;
        if (sc.func && tempinst.aliasdecl && tempinst.aliasdecl.toAlias().isFuncDeclaration())
        {
            /* Template function instantiation should run semantic3 immediately
             * for attribute inference.
             */
            doSemantic3 = true;
        }
        else if (sc.func)
        {
            /* A lambda function in template arguments might capture the
             * instantiated scope context. For the correct context inference,
             * all instantiated functions should run the semantic3 immediately.
             * See also compilable/test14973.d
             */
            foreach (oarg; tempinst.tdtypes)
            {
                auto s = getDsymbol(oarg);
                if (!s)
                    continue;

                if (auto td = s.isTemplateDeclaration())
                {
                    if (!td.literal)
                        continue;
                    assert(td.members && td.members.dim == 1);
                    s = (*td.members)[0];
                }
                if (auto fld = s.isFuncLiteralDeclaration())
                {
                    if (fld.tok == TOKreserved)
                    {
                        doSemantic3 = true;
                        break;
                    }
                }
            }
            //printf("[%s] %s doSemantic3 = %d\n", loc.toChars(), toChars(), doSemantic3);
        }
        if (doSemantic3)
            tempinst.trySemantic3(sc2);

        TemplateInstance ti = tempinst.tinst;
        int nest = 0;
        while (ti && !ti.deferred && ti.tinst)
        {
            ti = ti.tinst;
            // IN_LLVM replaced: if (++nest > 500)
            if (++nest > global.params.nestedTmpl) // LDC_FIXME: add testcase for this
            {
                global.gag = 0; // ensure error message gets printed
                tempinst.error("recursive expansion");
                fatal();
            }
        }
        if (ti && ti.deferred)
        {
            //printf("deferred semantic3 of %p %s, ti = %s, ti.deferred = %p\n", this, toChars(), ti.toChars());
            for (size_t i = 0;; i++)
            {
                if (i == ti.deferred.dim)
                {
                    ti.deferred.push(tempinst);
                    break;
                }
                if ((*ti.deferred)[i] == tempinst)
                    break;
            }
        }
    }

    if (tempinst.aliasdecl)
    {
        /* https://issues.dlang.org/show_bug.cgi?id=13816
         * AliasDeclaration tries to resolve forward reference
         * twice (See inuse check in AliasDeclaration.toAlias()). It's
         * necessary to resolve mutual references of instantiated symbols, but
         * it will left a true recursive alias in tuple declaration - an
         * AliasDeclaration A refers TupleDeclaration B, and B contains A
         * in its elements.  To correctly make it an error, we strictly need to
         * resolve the alias of eponymous member.
         */
        tempinst.aliasdecl = tempinst.aliasdecl.toAlias2();
    }

Laftersemantic:
    sc2.pop();
    _scope.pop();

    // Give additional context info if error occurred during instantiation
    if (global.errors != errorsave)
    {
        if (!tempinst.errors)
        {
            if (!tempdecl.literal)
                tempinst.error(tempinst.loc, "error instantiating");
            if (tempinst.tinst)
                tempinst.tinst.printInstantiationTrace();
        }
        tempinst.errors = true;
        if (tempinst.gagged)
        {
            // Errors are gagged, so remove the template instance from the
            // instance/symbol lists we added it to and reset our state to
            // finish clean and so we can try to instantiate it again later
            // (see https://issues.dlang.org/show_bug.cgi?id=4302 and https://issues.dlang.org/show_bug.cgi?id=6602).
            tempdecl.removeInstance(tempdecl_instance_idx);
            if (target_symbol_list)
            {
                // Because we added 'this' in the last position above, we
                // should be able to remove it without messing other indices up.
                assert((*target_symbol_list)[target_symbol_list_idx] == tempinst);
                target_symbol_list.remove(target_symbol_list_idx);
                tempinst.memberOf = null;                    // no longer a member
            }
            tempinst.semanticRun = PASSinit;
            tempinst.inst = null;
            tempinst.symtab = null;
        }
    }
    else if (errinst)
    {
        /* https://issues.dlang.org/show_bug.cgi?id=14541
         * If the previous gagged instance had failed by
         * circular references, currrent "error reproduction instantiation"
         * might succeed, because of the difference of instantiated context.
         * On such case, the cached error instance needs to be overridden by the
         * succeeded instance.
         */
        //printf("replaceInstance()\n");
        assert(errinst.errors);
        auto ti1 = TemplateInstanceBox(errinst);
        tempdecl.instances.remove(ti1);

        auto ti2 = TemplateInstanceBox(tempinst);
        tempdecl.instances[ti2] = tempinst;
    }

    static if (LOG)
    {
        printf("-TemplateInstance.semantic('%s', this=%p)\n", toChars(), this);
    }
}

// function used to perform semantic on AliasDeclaration
void aliasSemantic(AliasDeclaration ds, Scope* sc)
{
    //printf("AliasDeclaration::semantic() %s\n", toChars());
    if (ds.aliassym)
    {
        auto fd = ds.aliassym.isFuncLiteralDeclaration();
        auto td = ds.aliassym.isTemplateDeclaration();
        if (fd || td && td.literal)
        {
            if (fd && fd.semanticRun >= PASSsemanticdone)
                return;

            Expression e = new FuncExp(ds.loc, ds.aliassym);
            e = e.expressionSemantic(sc);
            if (e.op == TOKfunction)
            {
                FuncExp fe = cast(FuncExp)e;
                ds.aliassym = fe.td ? cast(Dsymbol)fe.td : fe.fd;
            }
            else
            {
                ds.aliassym = null;
                ds.type = Type.terror;
            }
            return;
        }

        if (ds.aliassym.isTemplateInstance())
            ds.aliassym.semantic(sc);
        return;
    }
    ds.inuse = 1;

    // Given:
    //  alias foo.bar.abc def;
    // it is not knowable from the syntax whether this is an alias
    // for a type or an alias for a symbol. It is up to the semantic()
    // pass to distinguish.
    // If it is a type, then type is set and getType() will return that
    // type. If it is a symbol, then aliassym is set and type is NULL -
    // toAlias() will return aliasssym.

    uint errors = global.errors;
    Type oldtype = ds.type;

    // Ungag errors when not instantiated DeclDefs scope alias
    auto ungag = Ungag(global.gag);
    //printf("%s parent = %s, gag = %d, instantiated = %d\n", toChars(), parent, global.gag, isInstantiated());
    if (ds.parent && global.gag && !ds.isInstantiated() && !ds.toParent2().isFuncDeclaration())
    {
        //printf("%s type = %s\n", toPrettyChars(), type.toChars());
        global.gag = 0;
    }

    /* This section is needed because Type.resolve() will:
     *   const x = 3;
     *   alias y = x;
     * try to convert identifier x to 3.
     */
    auto s = ds.type.toDsymbol(sc);
    if (errors != global.errors)
    {
        s = null;
        ds.type = Type.terror;
    }
    if (s && s == ds)
    {
        ds.error("cannot resolve");
        s = null;
        ds.type = Type.terror;
    }
    if (!s || !s.isEnumMember())
    {
        Type t;
        Expression e;
        Scope* sc2 = sc;
        if (ds.storage_class & (STCref | STCnothrow | STCnogc | STCpure | STCdisable))
        {
            // For 'ref' to be attached to function types, and picked
            // up by Type.resolve(), it has to go into sc.
            sc2 = sc.push();
            sc2.stc |= ds.storage_class & (STCref | STCnothrow | STCnogc | STCpure | STCshared | STCdisable);
        }
        ds.type = ds.type.addSTC(ds.storage_class);
        ds.type.resolve(ds.loc, sc2, &e, &t, &s);
        if (sc2 != sc)
            sc2.pop();

        if (e)  // Try to convert Expression to Dsymbol
        {
            s = getDsymbol(e);
            if (!s)
            {
                if (e.op != TOKerror)
                    ds.error("cannot alias an expression %s", e.toChars());
                t = Type.terror;
            }
        }
        ds.type = t;
    }
    if (s == ds)
    {
        assert(global.errors);
        ds.type = Type.terror;
        s = null;
    }
    if (!s) // it's a type alias
    {
        //printf("alias %s resolved to type %s\n", toChars(), type.toChars());
        ds.type = ds.type.typeSemantic(ds.loc, sc);
        ds.aliassym = null;
    }
    else    // it's a symbolic alias
    {
        //printf("alias %s resolved to %s %s\n", toChars(), s.kind(), s.toChars());
        ds.type = null;
        ds.aliassym = s;
    }
    if (global.gag && errors != global.errors)
    {
        ds.type = oldtype;
        ds.aliassym = null;
    }
    ds.inuse = 0;
    ds.semanticRun = PASSsemanticdone;

    if (auto sx = ds.overnext)
    {
        ds.overnext = null;
        if (!ds.overloadInsert(sx))
            ScopeDsymbol.multiplyDefined(Loc(), sx, ds);
    }
}
