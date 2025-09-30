/*
EXTRA_ARGS: -preview=bitfields -main
*/
struct S
{
    uint first;
    uint a1 : 6;
    uint b1 : 7;
    uint c1 : 14;
    uint d1 : 5;
    uint last;
}
S s;

class C
{
    uint first;
    uint a2 : 31;
    uint b2 : 1;
    uint c2 : 19;
    uint d2 : 13;
    uint last;
}
C c;
