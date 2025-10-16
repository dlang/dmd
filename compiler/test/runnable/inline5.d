// PERMUTE_ARGS: -inline -release -O

import imports.inline5a;

auto anon()
{
    return new class {
        pragma(inline, true)
        final int foo()
        {
            return fn2();
        }
    };
}

void main()
{
    anon().foo();
}
