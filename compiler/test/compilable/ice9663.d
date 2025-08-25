// https://issues.dlang.org/show_bug.cgi?id=9663

void main()
{
    int[1] a;
    int[] b = [1];

    a = 1;

    b[] = a;

    b = a;
}
