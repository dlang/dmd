module parser.test_astbase;

import dmd.astbase;
import dmd.visitor.transitive;
import support : afterEach, beforeEach;

@beforeEach
void initializeFrontend()
{
    import dmd.frontend : initDMD;
    initDMD();
}

@afterEach
void deinitializeFrontend()
{
    import dmd.frontend : deinitializeDMD;
    deinitializeDMD();
}

extern (C++) class CountingVisitor : ParseTimeTransitiveVisitor!ASTBase
{
    alias visit = ParseTimeTransitiveVisitor!ASTBase.visit;
    size_t variables;
    size_t payloadTypes;
    size_t attributes;

    override void visit(ASTBase.VarDeclaration declaration)
    {
        ++variables;
        ParseTimeTransitiveVisitor!ASTBase.visit(declaration);
    }

    override void visit(ASTBase.TypeIdentifier type)
    {
        ++payloadTypes;
        ParseTimeTransitiveVisitor!ASTBase.visit(type);
    }

    override void visit(ASTBase.IdentifierExp expression)
    {
        ++attributes;
        ParseTimeTransitiveVisitor!ASTBase.visit(expression);
    }
}

// Simple test to check whether ASTBase respects the interface
// that the parser expects from an AST family

void main()
{
    import dmd.astbase;
    import dmd.globals;
    import dmd.parse;
    import dmd.errorsink;

    scope parser = new Parser!ASTBase(null, null, false, new ErrorSinkStderr, null, false);
    assert(parser !is null);
}

@("enum union transitive visitor")
unittest
{
    import dmd.errorsink;
    import dmd.parse;

    enum source = q{
        enum union Result
        {
            @Marker case Some(Payload);
            case None();
        }
    };

    scope parser = new Parser!ASTBase(null, source, false, new ErrorSinkStderr, null, false);
    parser.nextToken();
    auto declarations = parser.parseModule();

    scope visitor = new CountingVisitor();
    foreach (declaration; *declarations)
        declaration.accept(visitor);

    assert(visitor.variables == 0);
    assert(visitor.payloadTypes == 1);
    assert(visitor.attributes == 1);
}
