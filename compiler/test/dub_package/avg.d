#!/usr/bin/env dub
/+dub.sdl:
dependency "dmd" path="../../.."
+/
/* This file contains an example on how to use the transitive visitor.
   It implements a visitor which computes the average function length from
   a *.d file.
 */

module examples.avg;

import dmd.astbase;
import dmd.errorsink;
import dmd.parse;
import dmd.target;
import dmd.visitor.transitive;

import dmd.globals;
import dmd.id;
import dmd.identifier;
import dmd.target;

import std.stdio;
import std.file;

extern(C++) class FunctionLengthVisitor(AST) : ParseTimeTransitiveVisitor!AST
{
    alias visit = ParseTimeTransitiveVisitor!AST.visit;
    ulong[] lengths;

    double getAvgLen(AST.Module m)
    {
        m.accept(this);

        if (lengths.length == 0)
            return 0;

        import std.algorithm;
        return double(lengths.sum)/lengths.length;
    }

    override void visitFuncBody(AST.FuncDeclaration fd)
    {
        lengths ~= fd.endloc.linnum - fd.loc.linnum;
        super.visitFuncBody(fd);
    }
}

void main()
{
    string fname = "testfiles/testavg.d";

    Id.initialize();
    global._init();
    target.os = Target.OS.linux;
    target.isX86_64 = (size_t.sizeof == 8);
    global.params.useUnitTests = true;
    ASTBase.Type._init();

    auto id = Identifier.idPool(fname);
    auto m = new ASTBase.Module(&(fname.dup)[0], id, false, false);
    auto input = readText(fname);
    input ~= '\0';

    scope p = new Parser!ASTBase(m, input, false, new ErrorSinkStderr(), null, false);
    p.nextToken();
    m.members = p.parseModule();

    scope visitor = new FunctionLengthVisitor!ASTBase();
    writeln("Average function length: ", visitor.getAvgLen(m));
}
