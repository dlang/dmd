import core.demangle;

extern(C) char* __cxa_demangle (const char* mangled_name,
                                                char* output_buffer,
                                                size_t* length,
                                                int* status) nothrow pure @trusted;

extern (C++) void thrower(int a) {
    throw new Exception("C++ ex");
}
void caller() {
    thrower(42);
}

void main()
{
    caller();
    __cxa_demangle(null, null, null, null); // make sure __cxa_demangle is linked
}
