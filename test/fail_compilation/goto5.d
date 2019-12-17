/* TEST_OUTPUT:
---
fail_compilation/goto5.d(17): Error: delegate `goto5.main.__foreachbody1` label `L1` is undefined
---
*/

struct S
{
    static int opApply(int delegate(ref int) dg)
    {
        return 0;
    }
}

void main()
{
    foreach(f; S)
    {
        asm
        {
            jmp L1;
        }
        goto L1;
    }
    L1:;
}
