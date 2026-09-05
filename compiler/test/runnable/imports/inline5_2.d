module imports.inline5_2;

import inline5;

template externDFunc(string name)
{
    pragma(mangle, reencodeMangled(name)) extern(D) void externDFunc();
}

void yield()
{
    externDFunc!"dummyFunc";
}
