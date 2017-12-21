#!/usr/bin/env dub
/+dub.sdl:
dependency "dmd" path="../.."
+/
void main()
{
    import dmd.astbase;
    import dmd.parse;

    scope parser = new Parser!ASTBase(null, null, false);
    assert(parser !is null);
}
