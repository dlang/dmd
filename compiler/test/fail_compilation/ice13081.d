/*
TEST_OUTPUT:
---
fail_compilation/ice13081.d(25): Error: undefined identifier `node`
        this[] = node.data ? data : node.data;
                 ^
fail_compilation/ice13081.d(25): Error: undefined identifier `data`
        this[] = node.data ? data : node.data;
                             ^
fail_compilation/ice13081.d(25): Error: undefined identifier `node`
        this[] = node.data ? data : node.data;
                                    ^
fail_compilation/ice13081.d(36): Error: template instance `ice13081.Cube!(SparseDataStore)` error instantiating
    Cube!SparseDataStore c;
    ^
---
*/

struct Cube(StorageT)
{
    StorageT datastore;
    alias datastore this;
    auto seed()
    {
        this[] = node.data ? data : node.data;
    }
}

class SparseDataStore
{
    auto opSlice() {}
}

void main()
{
    Cube!SparseDataStore c;
}
