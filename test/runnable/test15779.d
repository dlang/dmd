// REQUIRED_ARGS: -gx

// 15779

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
