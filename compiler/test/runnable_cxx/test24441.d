    version(CppRuntime_Gcc)
        version = Non_ms;
    else version(CppRuntime_Clang)
        version = Non_ms;

    version(Non_ms)
    {
        extern(C++) struct A
        {
            void foo(T)(T a);
        }

        void main()
        {
            A a;
            assert(a.foo!int.mangleof == "_ZN1A3fooIiEEvi");
        }
    }
