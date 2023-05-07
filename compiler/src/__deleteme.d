struct S(alias Func){ }

int func1(int a){ return a*2; }
int func2(int a){ return a*2; }

void main()
{
   auto a = S!func1();
   auto b = S!func2();

   a = b;

   auto c = S!((int a) => a*2)();
   auto d = S!((int a) => a*2)();

   c = d;
}