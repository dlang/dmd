/* TEST_OUTPUT:
---
fail_compilation/b20437.d(12): Error: cannot implicitly convert expression d of type void delegate() to immutable(void delegate())
fail_compilation/b20437.d(13): Error: cannot implicitly convert expression d of type void delegate() to shared(void delegate())
---
*/
// https://issues.dlang.org/show_bug.cgi?id=20437
void f()
{
    int x;
    void delegate() d = delegate() { x = 1; };
    immutable(void delegate()) bad1 = d;
    shared(void delegate()) bad2 = d;
}
