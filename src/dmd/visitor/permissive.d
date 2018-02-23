/**
 * Documentation:  https://dlang.org/phobos/dmd_visitor_permissive.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/visitor/permissive.d
 */

module dmd.visitor.permissive;

import dmd.astcodegen;
import dmd.visitor.parse_time;
import dmd.visitor.semantic;

/** PermissiveVisitor overrides all the visit methods in  the parent class
  * that assert(0) in order to facilitate the traversal of subsets of the AST.
  * It does not implement any visiting logic.
  */
extern(C++) class PermissiveVisitor(AST): ParseTimeVisitor!AST
{
    alias visit = ParseTimeVisitor!AST.visit;

    override void visit(AST.Dsymbol){}
    override void visit(AST.Parameter){}
    override void visit(AST.Statement){}
    override void visit(AST.Type){}
    override void visit(AST.Expression){}
    override void visit(AST.TemplateParameter){}
    override void visit(AST.Condition){}
    override void visit(AST.Initializer){}
}

/**
 * The PermissiveVisitor overrides the root AST nodes with
 * empty visiting methods.
 */
extern (C++) class SemanticTimePermissiveVisitor : SemanticVisitor
{
    alias visit = SemanticVisitor.visit;

    override void visit(ASTCodegen.Dsymbol){}
    override void visit(ASTCodegen.Parameter){}
    override void visit(ASTCodegen.Statement){}
    override void visit(ASTCodegen.Type){}
    override void visit(ASTCodegen.Expression){}
    override void visit(ASTCodegen.TemplateParameter){}
    override void visit(ASTCodegen.Condition){}
    override void visit(ASTCodegen.Initializer){}
}

