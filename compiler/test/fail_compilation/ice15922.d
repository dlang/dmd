/*
TEST_OUTPUT:
---
fail_compilation/ice15922.d(33): Error: function `ice15922.ValidSparseDataStore!int.ValidSparseDataStore.correctedInsert!false.correctedInsert` has no `return` statement, but is expected to return a value of type `int`
    DataT correctedInsert(bool CorrectParents)() {}
          ^
fail_compilation/ice15922.d(31): Error: template instance `ice15922.ValidSparseDataStore!int.ValidSparseDataStore.correctedInsert!false` error instantiating
        correctedInsert!(false);
        ^
fail_compilation/ice15922.d(36):        instantiated from here: `ValidSparseDataStore!int`
alias BasicCubeT = StorageAttributes!(ValidSparseDataStore!int);
                                      ^
fail_compilation/ice15922.d(24): Error: calling non-static function `insert` requires an instance of type `ValidSparseDataStore`
    enum hasInsertMethod = Store.insert;
                           ^
fail_compilation/ice15922.d(36): Error: template instance `ice15922.StorageAttributes!(ValidSparseDataStore!int)` error instantiating
alias BasicCubeT = StorageAttributes!(ValidSparseDataStore!int);
                   ^
---
*/

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
