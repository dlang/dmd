// PERMUTE_ARGS: -O

void sliceAssign()
{
    enum size_t len = 2_147_483_648UL;
    char* src, dst;
    dst[0 .. len] = src[0 .. len];
}
