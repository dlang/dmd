
// https://issues.dlang.org/show_bug.cgi?id=24069

typedef void (*fp_t)(int*);

float parse1(void f(int*));	// float (void (*)(int *))
float parse2(void (int*));
typedef int Dat;
float parse3(void (Dat*));

void test(float i)
{
      fp_t x;
      parse1(x);
      parse2(x);
      parse3(x);
}
