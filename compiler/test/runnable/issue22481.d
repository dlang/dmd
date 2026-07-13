// REQUIRED_ARGS: -inline

int v;

void f()
{
   for (int i = 1; i < 5; i++)
   {
      v = i;
      return;
   }
}

void main()
{
   f();
   assert(v == 1);
}
