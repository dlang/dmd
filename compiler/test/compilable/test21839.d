// https://github.com/dlang/dmd/issues/21839
// ICE with void[N].init passed to template function

void tf(U)(U) {}

void test()
{
    tf(void[16].init);
    tf(void[8].init);
}
