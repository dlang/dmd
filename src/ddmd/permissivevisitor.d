module ddmd.permissivevisitor;

import ddmd.astbase;
import ddmd.astbasevisitor;

/** PermissiveVisitor overrides all the visit methods in  the parent class
  * that assert(0) in order to facilitate the traversal of subsets of the AST.
  * It does not implement any visiting logic.
  */
class PermissiveVisitor: Visitor
{
    alias visit = super.visit;

    override void visit(ASTBase.Dsymbol){}
    override void visit(ASTBase.Parameter){}
    override void visit(ASTBase.Statement){}
    override void visit(ASTBase.Type){}
    override void visit(ASTBase.Expression){}
    override void visit(ASTBase.TemplateParameter){}
    override void visit(ASTBase.Condition){}
    override void visit(ASTBase.Initializer){}
}
