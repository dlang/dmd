#!/usr/bin/env dub
/+dub.sdl:
dependency "dmd:frontend" path="../../.."
+/

// Verify that dmd:frontend links without requiring backend symbols.
// Regression test for https://github.com/dlang/dmd/issues/23119

import dmd.frontend;

void main()
{
    initDMD();
}
