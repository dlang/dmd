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

void g(bool b)
{
   if (b)
   {
      v = 2;
      return;
   }
   else
   {
      v = 3;
   }

   v = 4;
   return;
}

void main()
{
   f();
   assert(v == 1);

   g(true);
   assert(v == 2);
}
