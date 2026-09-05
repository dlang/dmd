// https://github.com/dlang/dmd/issues/21899
// Bogus `matches conflicting symbols` error for exact same symbol
// REQUIRED_ARGS: -Icompilable/extra-files
// EXTRA_FILES: extra-files/test21899a.d extra-files/test21899b.d

import test21899a;
import test21899b;

void test()
{
    findTempDecl(0);
}
