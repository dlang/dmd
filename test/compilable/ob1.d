/* Should compile successfully
 */


struct Allocation {
    int* ptr;
    size_t length;
}

void canFind(scope Allocation);

int* malloc();
void free(int*);
void pitcher();
void borrow(scope int*);
void borrow2c(const scope int*, const scope int*);
void out1(out int*);


/*****************************/

@live int* foo1(int* p)
{
    return p;   // consumes owner
}

@live int* foo2()
{
    int* p = null;
    return p;      // consumes owner
}

@live int* foo3(int* p)
{
    scope int* q = p;  // borrows from p
    return p;          // use of p ends borrow in q
}

@live int* foo4(int* p)
{
    scope int* bq = p;          // borrow
    scope const int* cq = p;    // const borrow
    return p;                   // ends both borrows
}

/*******************************/

@live void foo5()
{
    auto p = malloc();
    scope(exit) free(p);
    pitcher();
}

/*******************************/

void deallocate(int* ptr, size_t length) @live
{
    canFind(Allocation(ptr, length)); // canFind() borrows ptr
    free(ptr);
}


/*******************************/


@live int* test1()
{
    auto p = malloc();
    scope b = p;
    return p;
}

@live int* test2()
{
    auto p = malloc();
    auto q = p;
    return q;
}

@live void test3()
{
    auto p = malloc();
    free(p);
}

@live void test4()
{
    auto p = malloc();
    borrow(p);
    free(p);
}

@live void test5()
{
    auto p = malloc();
    scope q = p;
    borrow2c(p, p);
    free(p);
}

@live void test6()
{
    int* p = void;
    out1(p);  // initialize
    free(p);  // consume
}


