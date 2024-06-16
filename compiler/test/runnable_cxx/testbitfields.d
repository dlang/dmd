// EXTRA_CPP_SOURCES: testbitfields_cpp.cpp
// EXTRA_SOURCES: extra-files/testbitfields_importc.c
// CXXFLAGS(linux osx freebsd dragonflybsd): -std=c++11

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

static import testbitfields_importc;

extern(C++) size_t getStructSize(T)();
extern(C++) size_t getStructAlign(T)();
extern(C++) void resetBitfield(T)(ref T data, const(char) *member);

bool checkType(S)()
{
    bool different;
    if (S.sizeof != getStructSize!S)
        different = true;
    if (S.alignof != getStructAlign!S)
        different = true;
    static foreach (member; __traits(allMembers, S))
    {{
        static if (member[0] != '_' && typeof(__traits(getMember, S, member)).stringof[0] != '_')
        {
            S dummyD;
            memset(&dummyD, 0xff, S.sizeof);
            __traits(getMember, dummyD, member) = 0;

            S* dummyC = cast(S*) malloc(getStructSize!S);
            memset(dummyC, 0xff, getStructSize!S);
            resetBitfield!S(*dummyC, member.ptr);
            if (S.sizeof == getStructSize!S && memcmp(&dummyD, dummyC, S.sizeof) != 0)
                different = true;
            free(dummyC);
        }
    }}
    if (different)
    {
        printf("Struct %s has different bitfield layout for C and D:\n", __traits(identifier, S).ptr);
        printf("  D: size=%zd align=%zd\n", S.sizeof, S.alignof);
        printf("  C: size=%zd align=%zd\n", getStructSize!S, getStructAlign!S);
        static foreach (member; __traits(allMembers, S))
        {{
            static if (member[0] != '_' && typeof(__traits(getMember, S, member)).stringof[0] != '_')
            {
                printf("  %s %s:\n", typeof(__traits(getMember, S, member)).stringof.ptr, member.ptr);
                printf("    D:");
                S dummyD;
                memset(&dummyD, 0xff, S.sizeof);
                __traits(getMember, dummyD, member) = 0;
                foreach (i; 0 .. S.sizeof)
                {
                    if (i % 4 == 0)
                        printf(" ");
                    printf("%02X", 0xff & ~(cast(ubyte*) &dummyD)[i]);
                }

                printf("\n    C:");
                S* dummyC = cast(S*) malloc(getStructSize!S);
                memset(dummyC, 0xff, getStructSize!S);
                resetBitfield!S(*dummyC, member.ptr);
                foreach (i; 0 .. getStructSize!S)
                {
                    if (i % 4 == 0)
                        printf(" ");
                    printf("%02X", 0xff & ~(cast(ubyte*) dummyC)[i]);
                }
                free(dummyC);
                printf("\n");
            }
        }}
    }
    return different;
}

int main()
{
    int ret;
    static foreach (name; __traits(allMembers, testbitfields_importc))
    {{
        alias S = __traits(getMember, testbitfields_importc, name);
        static if (is(S == struct) && name[0] != '_')
        {
            if (checkType!S)
                ret = 1;
        }
    }}
    return ret;
}
