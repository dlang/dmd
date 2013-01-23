

/**************************************/
// 6538

template allSatisfy(alias F, T...) { enum bool allSatisfy = true; }
template isIntegral(T) { enum bool isIntegral = true; }

/*
TEST_OUTPUT:
---
fail_compilation/ice6538.d(18): Error: cannot take a not yet instantiated symbol 'sizes' inside template constraint
fail_compilation/ice6538.d(23): Error: template ice6538.foo does not match any function template declaration. Candidates are:
fail_compilation/ice6538.d(18):        ice6538.foo(I...)(I sizes) if (allSatisfy!(isIntegral, sizes))
fail_compilation/ice6538.d(23): Error: template ice6538.foo(I...)(I sizes) if (allSatisfy!(isIntegral, sizes)) cannot deduce template function from argument types !()(int,int)
---
*/
void foo(I...)(I sizes)
if (allSatisfy!(isIntegral, sizes)) {}

void test6538a()
{
    foo(42, 86);
}

/*
TEST_OUTPUT:
---
fail_compilation/ice6538.d(36): Error: cannot take a not yet instantiated symbol 't1' inside template constraint
fail_compilation/ice6538.d(36): Error: cannot take a not yet instantiated symbol 't2' inside template constraint
fail_compilation/ice6538.d(41): Error: template ice6538.bar does not match any function template declaration. Candidates are:
fail_compilation/ice6538.d(36):        ice6538.bar(T1, T2)(T1 t1, T2 t2) if (allSatisfy!(isIntegral, t1, t2))
fail_compilation/ice6538.d(41): Error: template ice6538.bar(T1, T2)(T1 t1, T2 t2) if (allSatisfy!(isIntegral, t1, t2)) cannot deduce template function from argument types !()(int,int)
---
*/
void bar(T1, T2)(T1 t1, T2 t2)
if (allSatisfy!(isIntegral, t1, t2)) {}

void test6538b()
{
    bar(42, 86);
}

