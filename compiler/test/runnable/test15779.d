// REQUIRED_ARGS: -gx

// https://issues.dlang.org/show_bug.cgi?id=15779

import core.thread;

int main()
{
    try
    {
        bar();
    }
    catch (Exception e)
    {
    }
    return 0;
}

void bar()
{
    new Fiber({ throw new Exception("fly"); }).call();
}
