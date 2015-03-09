
import std.conv;
import std.path;

import ast;
import visitor;

class Namer : Visitor
{
    string name;
    this()
    {
    }

    alias super.visit visit;

    override void visit(FuncDeclaration ast)
    {
        name = "function " ~ ast.id;
    }

    override void visit(VarDeclaration ast)
    {
        name = "variable " ~ ast.id;
    }

    override void visit(VersionDeclaration ast)
    {
        ast.members[0][0].visit(this);
        name = "version " ~ name;
    }

    override void visit(TypedefDeclaration ast)
    {
        name = "typedef " ~ ast.id;
    }

    override void visit(MacroDeclaration ast)
    {
        name = "macro " ~ ast.id;
    }

    override void visit(StructDeclaration ast)
    {
        name = "struct " ~ ast.id;
    }

    override void visit(ExternCDeclaration ast)
    {
        ast.decls[0].visit(this);
        name = "externc " ~ name;
    }

    override void visit(EnumDeclaration ast)
    {
        if (ast.id.length)
            name = "enum " ~ ast.id;
        else
        {
            foreach(m; ast.members)
            {
                if (m.id)
                {
                    name = "enum " ~ m.id;
                    return;
                }
            }
        }
    }
}

class LongNamer : Namer
{
    alias super.visit visit;

    override void visit(FuncDeclaration ast)
    {
        name = "function " ~ ast.id;
        foreach(p; ast.params)
        {
            name ~= p.t ? p.t.mangle : "??";
        }
    }

}

string getName(Declaration decl)
{
    assert(decl);
    auto v = new Namer();
    decl.visit(v);
    return v.name;
}

string getLongName(Declaration decl)
{
    auto v = new LongNamer();
    decl.visit(v);
    return v.name;
}
