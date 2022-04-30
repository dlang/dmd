/* https://issues.dlang.org/show_bug.cgi?id=23058
 */

int printf(const char *s, ...);
void exit(int);

void assert(int b, int line)
{
    if (!b)
    {
        printf("failed test %d\n", line);
        exit(1);
    }
}


int arr[3][4] = { { 1,2,3,4 }, { 5,6,7,8 }, { 9,10,11,12 } };
int *p1 = &arr[1][2];

const int carr[3][4] = { { 1,2,3,4 }, { 5,6,7,8 }, { 9,10,11,12 } };
const int *p2 = &carr[1][2];

int arr3[1][1][1];
int **p3 = &arr3[0][0];
int *p4 = arr3[0][0];
int *p5 = &arr3[0][0][0];

int main()
{
    printf("arr[1][2] = %d\n", arr[1][2]);
    assert(arr[1][2] == 7, "1");

    printf("*p1 = %d\n", *p1);
    assert(*p1 == 7, "2");

    printf("carr[1][2] = %d\n", carr[1][2]);
    assert(carr[1][2] == 7, "3");

    printf("*p2 = %d\n", *p2);
    assert(*p2 == 7, "4");

    return 0;
}
