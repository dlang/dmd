/*
COMPILE_SEPARATELY:
EXTRA_SOURCES: imports/closure_this_sep_a.d
PERMUTE_ARGS:
*/

import imports.closure_this_sep_a;

void main()
{
    auto c = new C;
    assert(c.fd().get() == 42);
}
