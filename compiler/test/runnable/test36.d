// PERMUTE_ARGS:

import core.stdc.stdio;
interface IUnknown{
        extern(Windows):
        void func();
}
class ComObject :IUnknown
{
extern (Windows):
        void func()
        {printf(`comobject\n`);
        }
}

// https://issues.dlang.org/show_bug.cgi?id=24882
static assert(__traits(isCOMClass, ComObject));

interface IDataObject: IUnknown
{
        extern(Windows):
        void method();
}
package class invarianttest:ComObject, IDataObject
{
        invariant()
        {
                printf(`hello invariant\n`);
        }

extern (Windows):
        override void func()
        {
        int esp;
        version (D_InlineAsm_X86)
            asm{
                    mov esp,ESP;
            }
        version (D_InlineAsm_X86_64)
            asm{
                    mov esp,ESP;
            }
        printf("\n%d",esp);
        printf(`func`);
        }
        void method()
        {
                printf(`method\n`);
        }
}
int main()
{
        auto inst= new invarianttest;
        int esp;
        version (D_InlineAsm_X86)
            asm{
                    mov esp,ESP;
            }
        version (D_InlineAsm_X86_64)
            asm{
                    mov esp,ESP;
            }
        inst.func();
        inst.method();
        printf("\n%d\n",esp);
        version (D_InlineAsm_X86)
            asm{
                    mov esp,ESP;
            }
        version (D_InlineAsm_X86_64)
            asm{
                    mov esp,ESP;
            }
        printf("\n%d\n",esp);
        return 0;
}
