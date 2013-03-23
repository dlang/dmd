/*
TEST_OUTPUT:
---
fail_compilation/diag8948.d(25): Error: cannot implicitly convert expression (a) of type 'void function(int)' to 'void function(int, float)': Missing extra parameter #2 ('float')
fail_compilation/diag8948.d(31): Error: cannot implicitly convert expression (a) of type 'int function(int)' to 'float function(int)': Return type mismatch: ('int' vs 'float')
fail_compilation/diag8948.d(37): Error: cannot implicitly convert expression (& a) of type 'void function(int _param_0, int _param_1)' to 'void function(int, int) nothrow': Throw attribute mismatch ('throwable' vs 'nothrow')
fail_compilation/diag8948.d(43): Error: cannot implicitly convert expression (a) of type 'void function(int, float)' to 'void function(float, int)': Type mismatch at parameter #1 ('int' vs 'float')
fail_compilation/diag8948.d(49): Error: cannot implicitly convert expression (b) of type 'void function(int)' to 'void delegate(int)': Function type mismatch ('function' vs 'delegate')
fail_compilation/diag8948.d(50): Error: cannot implicitly convert expression (a) of type 'void delegate(int)' to 'void function(int)': Function type mismatch ('delegate' vs 'function')
fail_compilation/diag8948.d(56): Error: cannot implicitly convert expression (a) of type 'extern (C++) void function(int, float, string)' to 'extern (C) void function(int, float, string)': Linkage mismatch ('C++' vs 'C')
fail_compilation/diag8948.d(61): Error: cannot implicitly convert expression (__lambda1) of type 'int function(int _param_0) pure nothrow @safe' to 'int function()': Parameter count mismatch (1 vs 0)
fail_compilation/diag8948.d(62): Error: cannot implicitly convert expression (__lambda2) of type 'int function(int _param_0) pure nothrow @safe' to 'int function()': Parameter count mismatch (1 vs 0)
fail_compilation/diag8948.d(68): Error: cannot implicitly convert expression (a) of type 'void function(int _param_0, int _param_1)' to 'void function(int)': Parameter count mismatch (2 vs 1)
fail_compilation/diag8948.d(74): Error: cannot implicitly convert expression (a) of type 'void function(int, char)' to 'void function(int, float, char)': Parameter #2 ('float') is missing
fail_compilation/diag8948.d(80): Error: cannot implicitly convert expression (a) of type 'void function(int, float, char)' to 'void function(int, char)': Parameter count mismatch (3 vs 2)
fail_compilation/diag8948.d(86): Error: cannot implicitly convert expression (a) of type 'void function(int, float)' to 'void function(int)': Parameter count mismatch (2 vs 1)
---
*/

void main()
{
    {
        void function(int) a;
        void function(int, float) b;
        b = a;
    }

    {
        int function(int) a;
        float function(int) b;
        b = a;
    }

    {
        static void a(int, int) { }
        alias void function(int, int) nothrow B;
        B b = &a;
    }

    {
        void function(int, float) a;
        void function(float, int) b;
        b = a;
    }

    {
        void delegate(int) a;
        void function(int) b;
        a = b;
        b = a;
    }

    {
        extern(C++) void function(int, float, string) a;
        extern(C) void function(int, float, string) b;
        b = a;
    }

    {
        alias int function() Func;
        Func func1 = (int) { return 1; };
        Func func2 = (int a) => 1;
    }

    {
        void function(int, int) a;
        void function(int) b;
        b = a;
    }

    {
        void function(int, char) a;
        void function(int, float, char) b;
        b = a;
    }

    {
        void function(int, float, char) a;
        void function(int, char) b;
        b = a;
    }

    {
        void function(int, float) a;
        void function(int) b;
        b = a;
    }
}
