struct Allocation {
    int* ptr;
    size_t length;
}

void canFind(scope Allocation);

int* malloc();
void free(int*);
void pitcher();

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


