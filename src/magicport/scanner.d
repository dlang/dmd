
import std.conv;
import std.algorithm;
import std.stdio;
import std.string;
import std.path;

import tokens;
import ast;
import visitor;
import dprinter;
import typenames;

class Scanner : Visitor
{
    FuncDeclaration[] funcDeclarations;
    FuncDeclaration[string] funcDeclarationsTakingLoc;
    FuncBodyDeclaration[] funcBodyDeclarations;
    StructDeclaration[] structsUsingInheritance;
    StructDeclaration[] structDeclarations;
    StaticMemberVarDeclaration[] staticMemberVarDeclarations;
    CallExpr[] callExprs;
    ConstructDeclaration[] constructDeclarations;
    string agg;
    StructDeclaration scopedecl;
    int realdecls;

    this()
    {
    }

    void visit(int line = __LINE__)(Ast ast)
    {
        if (!ast)
            writeln(line);
        assert(ast);
        ast.visit(this);
    }

    ////////////////////////////////////

    override void visit(Module ast)
    {
        foreach(d; ast.decls)
            visit(d);
    }

    override void visit(ImportDeclaration ast)
    {
    }

    override void visit(FuncDeclaration ast)
    {
        realdecls++;
        funcDeclarations ~= ast;
        ast.structid = agg;
        visit(ast.type);
        if (ast.params.length && ast.params[0].t.id == "Loc")
            funcDeclarationsTakingLoc[ast.id] = ast;
        foreach(p; ast.params)
            visit(p);
        foreach(s; ast.fbody)
            visit(s);
        foreach(i; ast.initlist)
        {
            visit(i.func);
            foreach(a; i.args)
                visit(a);
        }
    }

    override void visit(FuncBodyDeclaration ast)
    {
        funcBodyDeclarations ~= ast;
        visit(ast.type);
        foreach(p; ast.params)
            visit(p);
        foreach(s; ast.fbody)
            visit(s);
        foreach(i; ast.initlist)
        {
            visit(i.func);
            foreach(a; i.args)
                visit(a);
        }
    }

    override void visit(StaticMemberVarDeclaration ast)
    {
        staticMemberVarDeclarations ~= ast;
        visit(ast.type);
        if (ast.xinit)
            visit(ast.xinit);
    }

    override void visit(VarDeclaration ast)
    {
        realdecls++;
        if (ast.type)
            visit(ast.type);
        if (ast.xinit)
            visit(ast.xinit);
    }

    override void visit(MultiVarDeclaration ast)
    {
        realdecls++;
        foreach(t; ast.types)
            if (t)
                visit(t);
        foreach(i; ast.inits)
            if (i)
                visit(i);
    }

    override void visit(ConstructDeclaration ast)
    {
        realdecls++;
        constructDeclarations ~= ast;
        visit(ast.type);
        foreach(a; ast.args)
            visit(a);
    }

    override void visit(VersionDeclaration ast)
    {
        auto rd = realdecls;
        ast.realdecls.length = ast.cond.length;
        foreach(e; ast.cond)
            if (e)
                visit(e);
        foreach(i, ds; ast.members)
        {
            realdecls = 0;
            foreach(d; ds)
                visit(d);
            ast.realdecls[i] = realdecls;
            rd += realdecls;
            break;
        }
        realdecls = rd;
    }

    override void visit(TypedefDeclaration ast)
    {
        realdecls++;
        visit(ast.t);
    }

    override void visit(MacroDeclaration ast)
    {
        realdecls++;
    }

    override void visit(MacroUnDeclaration ast)
    {
    }

    override void visit(StructDeclaration ast)
    {
        realdecls++;
        auto aggsave = agg;
        scope(exit) agg = aggsave;
        agg = ast.id;
        structDeclarations ~= ast;
        if (ast.superid)
            structsUsingInheritance ~= ast;
        if (ast.id == "Scope")
            scopedecl = ast;
        foreach(d; ast.decls)
            visit(d);
    }

    override void visit(AnonStructDeclaration ast)
    {
        realdecls++;
        foreach(d; ast.decls)
            visit(d);
    }

    override void visit(ExternCDeclaration ast)
    {
        foreach(d; ast.decls)
            visit(d);
    }

    override void visit(EnumDeclaration ast)
    {
        realdecls++;
        foreach(m; ast.members)
            if (m.val)
                visit(m.val);
    }

    override void visit(DummyDeclaration ast)
    {
    }

    override void visit(ErrorDeclaration ast)
    {
        realdecls++;
    }

    override void visit(ProtDeclaration ast)
    {
    }

    override void visit(LitExpr ast)
    {
    }

    override void visit(IdentExpr ast)
    {
    }

    override void visit(DotIdExpr ast)
    {
        visit(ast.e);
    }

    override void visit(CallExpr ast)
    {
        callExprs ~= ast;
        visit(ast.func);
        foreach(a; ast.args)
            visit(a);
    }

    override void visit(CmpExpr ast)
    {
        visit(ast.e1);
        visit(ast.e2);
    }

    override void visit(MulExpr ast)
    {
        visit(ast.e1);
        visit(ast.e2);
    }

    override void visit(AddExpr ast)
    {
        visit(ast.e1);
        visit(ast.e2);
    }

    override void visit(OrOrExpr ast)
    {
        visit(ast.e1);
        visit(ast.e2);
    }

    override void visit(AndAndExpr ast)
    {
        visit(ast.e1);
        visit(ast.e2);
    }

    override void visit(OrExpr ast)
    {
        visit(ast.e1);
        visit(ast.e2);
    }

    override void visit(XorExpr ast)
    {
        visit(ast.e1);
        visit(ast.e2);
    }

    override void visit(AndExpr ast)
    {
        visit(ast.e1);
        visit(ast.e2);
    }

    override void visit(AssignExpr ast)
    {
        visit(ast.e1);
        visit(ast.e2);
    }

    override void visit(DeclarationExpr ast)
    {
        visit(ast.d);
    }

    override void visit(PostExpr ast)
    {
        visit(ast.e);
    }

    override void visit(PreExpr ast)
    {
        visit(ast.e);
    }

    override void visit(PtrExpr ast)
    {
        visit(ast.e);
    }

    override void visit(AddrExpr ast)
    {
        visit(ast.e);
    }

    override void visit(NegExpr ast)
    {
        visit(ast.e);
    }

    override void visit(ComExpr ast)
    {
        visit(ast.e);
    }

    override void visit(DeleteExpr ast)
    {
        visit(ast.e);
    }

    override void visit(NotExpr ast)
    {
        visit(ast.e);
    }

    override void visit(IndexExpr ast)
    {
        visit(ast.e);
        foreach(a; ast.args)
            visit(a);
    }

    override void visit(CondExpr ast)
    {
        visit(ast.cond);
        visit(ast.e1);
        visit(ast.e2);
    }

    override void visit(CastExpr ast)
    {
        visit(ast.t);
        visit(ast.e);
    }

    override void visit(NewExpr ast)
    {
        if (ast.placement)
            visit(ast.placement);
        if (ast.dim)
            visit(ast.dim);
        visit(ast.t);
        foreach(a; ast.args)
            visit(a);
    }

    override void visit(OuterScopeExpr ast)
    {
        visit(ast.e);
    }

    override void visit(CommaExpr ast)
    {
        visit(ast.e1);
        visit(ast.e2);
    }

    override void visit(SizeofExpr ast)
    {
        if (ast.e)
            visit(ast.e);
        else
            visit(ast.t);
    }

    override void visit(ExprInit ast)
    {
        visit(ast.e);
    }

    override void visit(ArrayInit ast)
    {
        foreach(i; ast.xinit)
            visit(i);
    }

    override void visit(BasicType ast)
    {
    }

    override void visit(ClassType ast)
    {
    }

    override void visit(EnumType ast)
    {
    }

    override void visit(PointerType ast)
    {
        visit(ast.next);
    }

    override void visit(RefType ast)
    {
        visit(ast.next);
    }

    override void visit(ArrayType ast)
    {
        visit(ast.next);
        if (ast.dim)
            visit(ast.dim);
    }

    override void visit(FunctionType ast)
    {
        visit(ast.next);
        foreach(p; ast.params)
            visit(p);
    }

    override void visit(TemplateType ast)
    {
        visit(ast.next);
        visit(ast.param);
    }

    override void visit(Param ast)
    {
        if (ast.t)
            visit(ast.t);
        if (ast.def)
            visit(ast.def);
    }

    override void visit(CommentStatement ast)
    {
    }

    override void visit(CompoundStatement ast)
    {
        foreach(s; ast.s)
            visit(s);
    }

    override void visit(ReturnStatement ast)
    {
        if (ast.e)
            visit(ast.e);
    }

    override void visit(ExpressionStatement ast)
    {
        if (ast.e)
            visit(ast.e);
    }

    override void visit(VersionStatement ast)
    {
        foreach(e; ast.cond)
            if (e)
                visit(e);
        foreach(ss; ast.members)
            foreach(s; ss)
                visit(s);
    }

    override void visit(IfStatement ast)
    {
        visit(ast.e);
        visit(ast.sbody);
        if (ast.selse)
            visit(ast.selse);
    }

    override void visit(ForStatement ast)
    {
        if (ast.xinit)
            visit(ast.xinit);
        if (ast.cond)
            visit(ast.cond);
        if (ast.inc)
            visit(ast.inc);
        visit(ast.sbody);
    }

    override void visit(SwitchStatement ast)
    {
        visit(ast.e);
        foreach(s; ast.sbody)
            visit(s);
    }

    override void visit(CaseStatement ast)
    {
        visit(ast.e);
    }

    override void visit(BreakStatement ast)
    {
    }

    override void visit(ContinueStatement ast)
    {
    }

    override void visit(DefaultStatement ast)
    {
    }

    override void visit(WhileStatement ast)
    {
        visit(ast.e);
        visit(ast.sbody);
    }

    override void visit(DoWhileStatement ast)
    {
        visit(ast.e);
        visit(ast.sbody);
    }

    override void visit(GotoStatement ast)
    {
    }

    override void visit(LabelStatement ast)
    {
    }

};


Module collapse(Module[] mods, Scanner scan)
{
    Declaration[] decls;

    foreach(mod; mods)
        decls ~= resolveVersions(mod.decls);

    decls = removeDuplicates(decls);
    findProto(decls, scan);

    funcBodies(scan);
    staticMemberInit(scan);

    scopeCtor(scan);

    decls = stripDead(decls);

    return new Module("dmd.d", decls);
}

void funcBodies(Scanner scan)
{
    foreach(fd; scan.funcDeclarations)
    {
        foreach(fb; scan.funcBodyDeclarations)
        {
            if (fd.structid == fb.id && fd.id == fb.id2)
            {
                auto tf1 = new FunctionType(fd.type, fd.params);
                auto tf2 = new FunctionType(fb.type, fb.params);
                if (typeMatch(tf1, tf2))
                {
                    assert(!fd.hasbody && fb.hasbody, fd.id);
                    fd.fbody = fb.fbody;
                    fd.hasbody = true;
                    //assert(!(fd.comment && fb.comment), fd.id);
                    if (fb.comment) fd.comment = fb.comment;
                    if (fb.initlist)
                        fd.initlist = fb.initlist;
                    foreach(i; 0..tf1.params.length)
                    {
                        //if (tf2.params[i].id)
                            tf1.params[i].id = tf2.params[i].id;
                    }
                }
            }
        }
    }
}

void findProto(Declaration[] decls, Scanner scan)
{
    foreach(f1; scan.funcDeclarations)
    {
        foreach(f2; scan.funcDeclarations)
        {
            if (!f2.hasbody && f1.id == f2.id)
            {
                auto tf1 = new FunctionType(f1.type, f1.params);
                auto tf2 = new FunctionType(f2.type, f2.params);
                assert(tf1 && tf2);
                if (typeMatch(tf1, tf2))
                {
                    f2.skip = true;
                    if (f1.hasbody)
                    {
                        foreach(i; 0..tf1.params.length)
                        {
                            if (tf1.params[i].def && tf2.params[i].def)
                            {
                                assert(typeid(tf1.params[i].def) == typeid(tf2.params[i].def)); // Good enough for now
                            }
                            tf1.params[i].def = tf2.params[i].def;
                        }
                    }
                }
            }
        }
    }
}

void staticMemberInit(Scanner scan)
{
    foreach(vd1; scan.staticMemberVarDeclarations)
    {
        bool found = false;
    structloop:
        foreach(sd; scan.structDeclarations)
        {
            if (sd.id == vd1.id)
            {
                foreach(d; sd.decls)
                {
                    if (auto vd = cast(VarDeclaration)d)
                    {
                        if (vd.id == vd1.id2)
                        {
                            if (vd.comment && vd1.comment)
                                writeln("Warning: both prototype and definition have comments - ", vd.id);
                            if (vd1.comment) vd.comment = vd1.comment;
                            assert(!(vd.trailingcomment && vd1.trailingcomment) || vd.trailingcomment == vd1.trailingcomment, vd.id);
                            if (vd1.trailingcomment) vd.trailingcomment = vd1.trailingcomment;
                            vd.xinit = vd1.xinit;
                            found = true;
                            break structloop;
                        }
                    }
                }
            }
        }
        assert(found);
    }
}

Declaration[] removeDuplicates(Declaration[] decls)
{
    Declaration[] r;
    foreach(d; decls)
    {
        auto exists = false;
        foreach(x; r)
        {
            if (typeid(x) == typeid(d))
            {
                if (auto tdd = cast(TypedefDeclaration)d)
                {
                    auto d2 = cast(TypedefDeclaration)x;
                    if (tdd.id == d2.id)
                        exists = true;
                }
            }
        }
        if (!exists)
        {
            r ~= d;
        }
    }
    return r;
}

Declaration[] resolveVersions(Declaration[] decls)
{
    Declaration[] r;
    foreach(d; decls)
    {
        if (auto vd = cast(VersionDeclaration)d)
        {
            // Do not emit static ifs for include guards
            if (vd.cond.length == 1)
            {
                auto ne = cast(NotExpr)vd.cond[0];
                if (ne)
                {
                    auto ie = cast(IdentExpr)ne.e;
                    if (ie.id.endsWith("_H"))
                    {
                        r ~= resolveVersions(vd.members[0]);
                        continue;
                    }
                }
                if (vd.realdecls[0] == 0)
                    continue;
            }
        }
        r ~= d;
    }
    return r;
}

// Generate initializers for all of Scope's variables from its default ctor
// And generate copy ctor
void scopeCtor(Scanner scan)
{
    foreach(f; scan.funcDeclarations)
    {
        if (f.type.id == f.id && f.id == "Scope" && f.params.length == 0)
        {
            Init[string] inits;
            Statement[] cbody;
            foreach(s; f.fbody)
            {
                if (cast(CommentStatement)s)
                    continue;
                auto es = cast(ExpressionStatement)s;
                assert(es);
                auto ae = cast(AssignExpr)es.e;
                assert(ae);
                auto de = cast(DotIdExpr)ae.e1;
                assert(de);
                auto te = cast(IdentExpr)de.e;
                assert(te);
                assert(te.id == "this");
                inits[de.id] = new ExprInit(ae.e2);
                cbody ~= new ExpressionStatement(new AssignExpr("=", de, new DotIdExpr(".", new IdentExpr("sc"), de.id)), null);
            }
            foreach(m; scan.scopedecl.decls)
            {
                assert(!cast(MultiVarDeclaration)m);
                auto vd = cast(VarDeclaration)m;
                if (vd && !(vd.stc && STCstatic))
                {
                    assert(!vd.xinit);
                    auto p = vd.id in inits;
                    if (p)
                    {
                        vd.xinit = *p;
                    }
                }
            }
            auto p = [new Param(new RefType(new ClassType("Scope")), "sc", null)];
            scan.scopedecl.decls ~= new FuncDeclaration(new ClassType("Scope"), "Scope", p, cbody, 0, null, true, null);
            return;
        }
    }
}

Declaration[] stripDead(Declaration[] decls, bool inclass = false)
{
    Declaration[] r;
    foreach(d; decls)
    {
        if (cast(DummyDeclaration)d ||
            cast(FuncBodyDeclaration)d ||
            cast(StaticMemberVarDeclaration)d ||
            cast(ImportDeclaration)d ||
            cast(MacroUnDeclaration)d)
            continue;
        if (auto vd = cast(VarDeclaration)d)
        {
            if (vd.id.endsWith("_H"))
                continue;
            if (vd.stc & STCextern)
                continue;
            switch(vd.id)
            {
            case "__C99FEATURES__":
            case "__USE_ISOC99":
            case "LOG":
            case "LOGSEMANTIC":
                continue;
            default:
                break;
            }
        }
        if (auto fd = cast(FuncDeclaration)d)
        {
            if (!inclass && !fd.fbody.length)
                continue;
            if (inclass && fd.type.id == fd.id && fd.params.length == 0 && dropdefaultctor.canFind(fd.id))
                continue;
        }
        if (auto cd = cast(ExternCDeclaration)d)
        {
            cd.decls = cd.decls.stripDead();
            if (!cd.decls.length)
                continue;
        }
        if (auto vd = cast(VersionDeclaration)d)
        {
            auto ne = cast(NotExpr)vd.cond[0];
            auto ie = ne ? cast(IdentExpr)ne.e : null;
            if (ie && ie.id == "SYSCONFDIR")
            {
                r ~= vd.members[0].stripDead();
                continue;
            }
            size_t n;
            foreach(ref xdecls; vd.members)
            {
                xdecls = xdecls.stripDead();
                n += xdecls.length;
            }
            if (!n)
                continue;
        }
        if (auto td = cast(TypedefDeclaration)d)
        {
            if (td.t.id == "union tree_node")
                continue;
            if (td.t.id == "struct TYPE")
                continue;
        }
        if (auto md = cast(MacroDeclaration)d)
        {
            if (md.id == "assert")
                continue;
        }
        if (auto sd = cast(StructDeclaration)d)
        {
            sd.decls = sd.decls.stripDead(true);
        }
        r ~= d;
    }
    return r;
}
