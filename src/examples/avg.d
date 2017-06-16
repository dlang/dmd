/* This file contains an example on how to use the transitive visitor.
   It implements a visitor which computes the average function length from
   a *.d file.
 */

module examples.avg;

import ddmd.astbase;
import ddmd.parse;
import ddmd.transitivevisitor;

import ddmd.globals;
import ddmd.id;
import ddmd.identifier;

import std.stdio;
import std.file;

class FunctionLengthVisitor : TransitiveVisitor
{
    alias visit = super.visit;
    ulong[] lengths;

    double getAvgLen(ASTBase.Module m)
    {
        m.accept(this);

        if (lengths.length == 0)
            return 0;

        import std.algorithm;
        return double(lengths.sum)/lengths.length;
    }

    override void visitFuncBody(ASTBase.FuncDeclaration fd)
    {
        lengths ~= fd.endloc.linnum - fd.loc.linnum;
        super.visitFuncBody(fd);
    }
}

void main()
{
    string fname = "examples/testavg.d";

    Id.initialize();
    global._init();
    global.params.isLinux = true;
    global.params.is64bit = (size_t.sizeof == 8);
    global.params.useUnitTests = true;
    ASTBase.Type._init();

    auto id = Identifier.idPool(fname);
    auto m = new ASTBase.Module(&(fname.dup)[0], id, false, false);
    auto input = readText(fname);

    scope p = new Parser!ASTBase(m, input, false);
    p.nextToken();
    m.members = p.parseModule();

    scope visitor = new FunctionLengthVisitor();
    writeln("Average function length: ", visitor.getAvgLen(m));
}
