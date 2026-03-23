// REQUIRED_ARGS: -preview=nosharedaccess

import core.atomic;

struct List
{
    size_t gen;
    List* next;
}

void main()
{
    shared(List) head;
    assert(cas(&head, shared(List)(0, null), shared(List)(1, cast(List*)1)));
}
