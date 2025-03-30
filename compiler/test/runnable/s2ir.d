/*
RUN_OUTPUT:
---
hello
world
foo
Success
---
*/

import core.stdc.stdio;

/***********************************/

void test1()
{
    int i;
    __gshared int j;

    version (D_InlineAsm_X86)
    {
        asm
        {
            naked       ;
            mov EAX, i  ;
        }
      version(D_PIC)
      {}
      else version (D_PIE)
      {}
      else
      {
        asm
        {
            mov EAX, j  ;
        }
      }
    }
}

/***********************************/

int main()
{
    for (int i = 0; ; i++)
    {
        if (i == 10)
            break;
    }

    string[] a = new string[3];
    a[0] = "hello";
    a[1] = "world";
    a[2] = "foo";

    foreach (string s; a)
        printf("%.*s\n", cast(int)s.length, s.ptr);

    switch (1)
    {
        default:
            break;
    }

    switch ("foo"w)
    {
        case "foo":
            break;
        default: assert(0);
    }

    switch (1)
    {
        case 1:
            try
            {
                goto default;
            }
            catch (Throwable o)
            {
            }
            break;

        default:
            break;
    }

    switch (1)
    {
        case 1:
            try
            {
                goto case 2;
            }
            catch (Throwable o)
            {
            }
            break;

        case 2:
            break;

        default: assert(0);
    }

    printf("Success\n");
    return 0;
}
