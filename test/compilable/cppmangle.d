
// Test C++ name mangling.
// See Bug 7024, Bug 10058

version(linux):
extern(C++):

/**********************************/

void test1(void*)
{
}

static assert(test1.mangleof  == "_Z5test1Pv");

/**********************************/

void test2(void function(void*))
{
}

static assert(test2.mangleof  == "_Z5test2PFvPvE");

/**********************************/

void test3(void* function(void*))
{
}

static assert(test3.mangleof  == "_Z5test3PFPvS_E");

/**********************************/

void test4(void function(void*), void*)
{
}

static assert(test4.mangleof  == "_Z5test4PFvPvES_");

/**********************************/

void test5(void* function(void*), void*)
{
}

static assert(test5.mangleof  == "_Z5test5PFPvS_ES_");

/**********************************/

void test6(void* function(void*), void* function(void*))
{
}

static assert(test6.mangleof  == "_Z5test6PFPvS_ES1_");

/**********************************/

void test7(void function(void*), void*, void*)
{
}

static assert(test7.mangleof  == "_Z5test7PFvPvES_S_");

/**********************************/

void test8(void* function(void*), void*, void*)
{
}

static assert(test8.mangleof  == "_Z5test8PFPvS_ES_S_");

/**********************************/

void test9(void* function(void*), void* function(void*), void*)
{
}

static assert(test9.mangleof  == "_Z5test9PFPvS_ES1_S_");

/**********************************/

void test10(void* function(void*), void* function(void*), void* function(void*))
{
}

static assert(test10.mangleof == "_Z6test10PFPvS_ES1_S1_");

/**********************************/

void test11(void* function(void*), void* function(const (void)*))
{
}

static assert(test11.mangleof == "_Z6test11PFPvS_EPFS_PKvE");

/**********************************/

void test12(void* function(void*), void* function(const (void)*), const(void)* function(void*))
{
}

static assert(test12.mangleof == "_Z6test12PFPvS_EPFS_PKvEPFS3_S_E");

