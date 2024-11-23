/*
TEST_OUTPUT:
---
fail_compilation/fail6781.d(13): Error: undefined identifier `some_error`
    some_error;
    ^
fail_compilation/fail6781.d(18): Error: template instance `fail6781.C6781.makeSortedIndices.bug6781!(greater)` error instantiating
        bug6781!greater();
        ^
---
*/
void bug6781(alias xxx)() {
    some_error;
}
struct C6781 {
    void makeSortedIndices() {
        int greater;
        bug6781!greater();
    }
}
