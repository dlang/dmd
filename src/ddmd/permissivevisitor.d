module ddmd.permissivevisitor;

import ddmd.astbase;
import ddmd.astbasevisitor;

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
