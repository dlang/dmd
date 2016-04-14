/*
TEST_OUTPUT:
---
fail_compilation/ice15922.d(12): Error: function ice15922.ValidSparseDataStore!int.ValidSparseDataStore.correctedInsert!false.correctedInsert has no return statement, but is expected to return a value of type int
fail_compilation/ice15922.d(10): Error: template instance ice15922.ValidSparseDataStore!int.ValidSparseDataStore.correctedInsert!false error instantiating
fail_compilation/ice15922.d(15):        instantiated from here: ValidSparseDataStore!int
fail_compilation/ice15922.d(3): Error: need 'this' for 'insert' of type 'pure @nogc @safe int()'
fail_compilation/ice15922.d(15): Error: template instance ice15922.StorageAttributes!(ValidSparseDataStore!int) error instantiating
---
*/
#line 1
template StorageAttributes(Store)
{
    enum hasInsertMethod = Store.insert;
    enum hasFullSlice = Store.init[];
}
struct ValidSparseDataStore(DataT)
{
    DataT insert()
    {
        correctedInsert!(false);
    }
    DataT correctedInsert(bool CorrectParents)() {}
    auto opSlice() inout {}
}
alias BasicCubeT = StorageAttributes!(ValidSparseDataStore!int);
