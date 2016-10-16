module mydll;

import core.stdc.stdio;

export int saved_var;

export int multiply10(int x)
{
    saved_var = x;

    return x * 10;
}

