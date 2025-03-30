/* https://issues.dlang.org/show_bug.cgi?id=23058
 */

char s1[5] = "hello";
char s2[6] = "hello";
char s3[7] = "hello";

void test()
{
    char s1[5] = "hello";
    char s2[6] = "hello";
    char s3[7] = "hello";
    char s4[50] = "hello";
}
