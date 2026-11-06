// https://github.com/dlang/dmd/issues/21891

import imports.imp21891a;
import imports.imp21891b;

void main()
{
    imports.imp21891a.executable_code21891 a;
    a.code = null;
    assert(a.code is null);

    imports.imp21891b.executable_code21891 b;
    b.code = null;
    assert(b.code is null);
}
