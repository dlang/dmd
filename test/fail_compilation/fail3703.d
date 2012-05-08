// Issue 3703 - static array assignment

void main()
{
    int[1] a = [1];
    int[2] b;

    b = a;  // should make compile error
}
