#!/usr/bin/env dub
/+dub.sdl:
dependency "dmd" path="../../.."
+/
void main()
{
    import dmd.astbase;
    import dmd.globals;
    import dmd.parse;
    import dmd.errorsink;

    scope parser = new Parser!ASTBase(null, null, false, new ErrorSinkStderr, null, false);
    assert(parser !is null);
}
