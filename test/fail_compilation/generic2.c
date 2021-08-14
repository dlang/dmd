/* TEST_OUTPUT:
---
fail_compilation/generic2.c(103): Error: only one `default` allowed in generic-assoc-list
---
*/

#line 100

void test()
{
    int e3 = _Generic(1, default:2, default:3);
}



