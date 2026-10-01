// https://github.com/dlang/dmd/issues/23166

import imports.imp23166;

void main()
{
    auto s = new BrokenStruct();
    assert(s !is null);
}
