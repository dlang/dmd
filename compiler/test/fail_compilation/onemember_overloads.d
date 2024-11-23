/*
TEST_OUTPUT:
---
fail_compilation/onemember_overloads.d(51): Error: none of the overloads of `skipOver` are callable using argument types `()`
    skipOver();
            ^
fail_compilation/onemember_overloads.d(47):        Candidates are: `onemember_overloads.skipOver(string)`
void skipOver(string);
     ^
fail_compilation/onemember_overloads.d(40):                        `skipOver(alias pred = (a, b) => a == b)`
template skipOver(alias pred = (a, b) => a == b)
^
fail_compilation/onemember_overloads.d(42):          - Containing: `skipOver(Haystack, Needles...)(ref Haystack haystack, Needles needles)`
    bool skipOver(Haystack, Needles...)(ref Haystack haystack, Needles needles) => true;
         ^
fail_compilation/onemember_overloads.d(43):          - Containing: `skipOver(R)(ref R r1)`
    bool skipOver(R)(ref R r1) => true;
         ^
fail_compilation/onemember_overloads.d(44):          - Containing: `skipOver(R, Es...)(ref R r, Es es)`
    bool skipOver(R, Es...)(ref R r, Es es) => true;
         ^
fail_compilation/onemember_overloads.d(52): Error: template `t2` is not callable using argument types `!()()`
    t2();
      ^
fail_compilation/onemember_overloads.d(55):        Candidate is: `t2(T)`
template t2(T)
^
fail_compilation/onemember_overloads.d(57):          - Containing: `t2(string)`
    bool t2(string);
         ^
fail_compilation/onemember_overloads.d(58):          - Containing: `t2(int[])`
    bool t2(int[]);
         ^
fail_compilation/onemember_overloads.d(59):          - Containing: `t2(R)(R)`
    bool t2(R)(R);
         ^
---
*/

template skipOver(alias pred = (a, b) => a == b)
{
    bool skipOver(Haystack, Needles...)(ref Haystack haystack, Needles needles) => true;
    bool skipOver(R)(ref R r1) => true;
    bool skipOver(R, Es...)(ref R r, Es es) => true;
}

void skipOver(string);

void main()
{
    skipOver();
    t2();
}

template t2(T)
{
    bool t2(string);
    bool t2(int[]);
    bool t2(R)(R);
}
