/* TEST_OUTPUT:
---
fail_compilation/fail18093.d(25): Error: function `void fail18093.GenericTransitiveVisitor!(ASTCodegen).GenericTransitiveVisitor.ParseVisitMethods!(ASTCodegen).visit()` does not override any function, did you mean to override `extern (C++) void fail18093.ParseTimeVisitor!(ASTCodegen).ParseTimeVisitor.visit()`?
    override void visit() {}
                  ^
fail_compilation/fail18093.d(30): Error: mixin `fail18093.GenericTransitiveVisitor!(ASTCodegen).GenericTransitiveVisitor.ParseVisitMethods!(ASTCodegen)` error instantiating
    mixin ParseVisitMethods!AST;
    ^
fail_compilation/fail18093.d(33): Error: template instance `fail18093.GenericTransitiveVisitor!(ASTCodegen)` error instantiating
alias SemanticTimeTransitiveVisitor = GenericTransitiveVisitor!ASTCodegen;
                                      ^
---
 * https://issues.dlang.org/show_bug.cgi?id=18093
 */


struct ASTCodegen {}

extern (C++) class ParseTimeVisitor(AST)
{
    void visit() {}
}
template ParseVisitMethods(AST)
{
    override void visit() {}
}

class GenericTransitiveVisitor(AST) : ParseTimeVisitor!AST
{
    mixin ParseVisitMethods!AST;
}

alias SemanticTimeTransitiveVisitor = GenericTransitiveVisitor!ASTCodegen;
