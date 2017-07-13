module ddmd.permissivevisitor;

import ddmd.astbase;
import ddmd.astbasevisitor;

/** PermissiveVisitor overrides all the visit methods in  the parent class
  * that assert(0) in order to facilitate the traversal of subsets of the AST.
  * It does not implement any visiting logic.
  */
class PermissiveVisitor(AST): Visitor!AST
{
    alias visit = Visitor!AST.visit;

    override void visit(AST.Dsymbol){}
    override void visit(AST.Parameter){}
    override void visit(AST.Statement){}
    override void visit(AST.Type){}
    override void visit(AST.Expression){}
    override void visit(AST.TemplateParameter){}
    override void visit(AST.Condition){}
    override void visit(AST.Initializer){}
}
