/* TEST_OUTPUT:
---
fail_compilation/fail17969.d(14): Error: no property `sum` for type `fail17969.__lambda_L14_C1!(int[]).__lambda_L14_C1.MapResult2!((b) => b)`
alias fun = a => MapResult2!(b => b).sum;
                 ^
fail_compilation/fail17969.d(20):        struct `MapResult2` defined here
struct MapResult2(alias fun)
^
---
 * https://issues.dlang.org/show_bug.cgi?id=17969
 */


alias fun = a => MapResult2!(b => b).sum;

int[] e;
static assert(!is(typeof(fun(e)) == void));
void foo() { fun(e); }

struct MapResult2(alias fun)
{
    int[] _input;
}
