/*
TEST_OUTPUT:
---
fail_compilation/fail22634.d(11): Error: more than 65535 symbols with name `i` generated
    static foreach(i; 0..65537)
    ^
---
*/
void main()
{
    static foreach(i; 0..65537)
    {
    }
}
