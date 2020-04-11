/*
REQUIRED_ARGS:
EXTRA_FILES: extra-files/test15.txt
TEST_OUTPUT:
---
---
*/

import std.array;
import core.vararg;
import std.string;
import std.stdio : File;

extern (C)
{
    int printf(const char*, ...);
}

/************************************/

void test21()
{
    int[string] esdom;
    auto f = File("runnable_phobos/extra-files/test15.txt", "r");

    foreach(it; f.byLine())
        esdom[it.idup] = 0;

    esdom.rehash;
}

/************************************/

void test26()
{
    string[] instructions = std.array.split("a;b;c", ";");

    foreach(ref string instr; instructions)
    {
        std.string.strip(instr);
    }

    foreach(string instr; instructions)
    {
        printf("%.*s\n", cast(int)instr.length, instr.ptr);
    }
}

/************************************/

class StdString
{
     alias std.string.format toString;
}

void test61()
{
    int i = 123;
    StdString g = new StdString();
    string s = g.toString("%s", i);
    printf("%.*s\n", cast(int)s.length, s.ptr);
    assert(s == "123");
}

/************************************/

int main()
{
    test21();
    test26();
    test61();

    printf("Success\n");
    return 0;
}
