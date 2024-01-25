/*
TEST_OUTPUT:
---
fail_compilation/fail53.d(27): Error: function `opEquals` is not callable using argument types `(int)`
fail_compilation/fail53.d(27):        cannot pass argument `i` of type `int` to parameter `Object o`
/home/ryuukk/dev/dmd/compiler/test/../../druntime/import/object.d(214):        `object.Object.opEquals(Object o)` declared here
---
*/

// $HeadURL$
// $Date$
// $Author$

// @author@	Thomas Kuehne <thomas-dloop@kuehne.thisisspam.cn>
// @date@	2005-01-22
// @uri@	news:csvvet$2g4$1@digitaldaemon.com
// @url@	nntp://news.digitalmars.com/digitalmars.D.bugs/2741

// __DSTRESS_ELINE__ 17

module dstress.nocompile.bug_mtype_507_A;

int main()
{
    Object o;
    int i;
    if (i == o)
    {
        return -1;
    }
    return 0;
}
