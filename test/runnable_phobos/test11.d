// REQUIRED_ARGS:

extern(C) int printf(const char*, ...);

/**************************************/

class A63
{
     private import std.file;
     alias std.file.getcwd getcwd;
}

void test63()
{
     A63 f = new A63();
     auto s = f.getcwd();
     printf("%.*s\n", cast(int)s.length, s.ptr);
}

/**************************************/

int main(string[] argv)
{
    test63();

    printf("Success\n");
    return 0;
}


