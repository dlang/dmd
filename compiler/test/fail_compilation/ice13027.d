/*
TEST_OUTPUT:
---
fail_compilation/ice13027.d(11): Error: template instance `b!"c"` template `b` is not defined
    scope a = b!"c";
              ^
---
*/
void main()
{
    scope a = b!"c";
}
