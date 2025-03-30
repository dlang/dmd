// https://issues.dlang.org/show_bug.cgi?id=22585

extern const unsigned char array[];
const unsigned char array[4] = { 0, 1, 2, 3 };

int main()
{
    return 0;
}
