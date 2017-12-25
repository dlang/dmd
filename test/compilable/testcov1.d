// EXTRA_SOURCES: imports/testcov1a.d imports/testcov1b.d
// PERMUTE_ARGS:
// REQUIRED_ARGS: -cov

import core.stdc.string;
import testcov1a;

version(D_Coverage)
{
    // Good
}
else
{
    static assert(0, "Missing 'D_Coverage' version identifier");
}
