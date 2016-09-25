// PERMUTE_ARGS:

import std.stdio;
interface IUnknown{
        extern(Windows):
        void func();
}
class ComObject :IUnknown
{
extern (Windows):
        void func()
        {writefln(`comobject`);
        }
}
interface IDataObject: IUnknown
{
        extern(Windows):
        void method();
}
package class invarianttest:ComObject, IDataObject
{
        invariant()
        {
                writefln(`hello invariant`);
        }

extern (Windows):
        override void func()
        {
        int esp;
        asm{
                mov esp,ESP;
        }
        printf("\n%d",esp);
        printf(`func`);
        }
        void method()
        {
                writefln(`method`);
        }
}
int main()
{
        auto inst= new invarianttest;
        int esp;
        asm{
                mov esp,ESP;
        }
        inst.func();
        inst.method();
        writefln("\n%d",esp);
        asm{
                mov esp,ESP;
        }
        writefln("\n%d",esp);
        return 0;
}

