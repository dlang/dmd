/*
TEST_OUTPUT:
---
fail_compilation/fail55.d(24): Error: function `opCmp` is not callable using argument types `(int)`
fail_compilation/fail55.d(24):        cannot pass argument `0` of type `int` to parameter `Object o`
/home/ryuukk/dev/dmd/compiler/test/../../druntime/import/object.d(160):        `object.Object.opCmp(Object o)` declared here
---
*/

// $HeadURL$
// $Date$
// $Author$

// @author@ zwang <nehzgnaw@gmail.com>
// @date@   2005-02-03
// @uri@    news:cttjjg$4i0$2@digitaldaemon.com

// __DSTRESS_ELINE__ 14

module dstress.nocompile.bug_mtype_507_D;

void test()
{
    0 < Exception;
}
