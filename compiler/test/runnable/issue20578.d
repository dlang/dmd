// REQUIRED_ARGS: -inline

int fun(string[])
{
   if (false)
      static foreach(m; [1,2,3] ) { }

   return 0;
}

int main(string[] args)
{
   return fun(args);
}
