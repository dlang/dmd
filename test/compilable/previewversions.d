/**
REQUIRED_ARGS: -preview=in -preview=dip1000
*/

version (D_Preview_dip1000) {}
else static assert(0, "Missing `D_Preview_dip1000`");

version (D_Preview_in) {}
else static assert(0, "Missing `D_Preview_in`");

version (D_Preview_dip1008)
{
    static assert(0, "Found unexpected version `D_Preview_dip1008`");
}
