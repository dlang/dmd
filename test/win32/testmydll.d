import core.runtime;
import std.stdio;

import mydll;

//version=DYNAMIC_LOAD;

version (DYNAMIC_LOAD)
{
    import core.sys.windows.windows;

    alias MyClass function() getMyClass_fp;

    int main()
    {   HMODULE h;
        FARPROC fp;

        getMyClass_fp getMyClass;
        MyClass c;

        printf("Start Dynamic Link...\n");

        h = cast(HMODULE) Runtime.loadLibrary("mydll.dll");
        if (h is null)
        {
            printf("error loading mydll.dll\n");
            return 1;
        }
	printf("mydll.dll loaded\n");

        fp = GetProcAddress(h, "D5mydll10getMyClassFZC5mydll7MyClass");
        if (fp is null)
        {   printf("error loading symbol getMyClass()\n");
            return 1;
        }
	printf("GetProcAddress succeeded\n");

        getMyClass = cast(getMyClass_fp) fp;
        c = (*getMyClass)();
	printf("(*getMyClass)() succeeded\n");
        foo(c);
	printf("foo(c) succeeded\n");

        if (!Runtime.unloadLibrary(h))
        {   printf("error freeing mydll.dll\n");
            return 1;
        }

        printf("End...\n");
        return 0;
    }
}
else
{   // static link the DLL

    int main()
    {
        printf("Start Static Link...\n");
        //MyDLL_Initialize(std.gc.getGCHandle());
        foo(getMyClass());
        //MyDLL_Terminate();
        printf("End...\n");
        return 0;
    }
}


void foo(MyClass c)
{
    printf("foo()\n");
    string s = c.concat("Hello", "world!");
    writefln(s);
    c.free(s);
    delete c;
    printf("foo() done\n");
}
