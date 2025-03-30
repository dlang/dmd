module parser.test_astbase;

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
