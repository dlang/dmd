template recMove(int i, X...)
{
  void recMove()
    {
      X[i] = X[i+1];
      // I know the code is logically wrong, should test (i+2 < X.length)
      static if(i+1 < X.length) recMove!(i+1, X);
    }
}

void main()
{
  int a, b;
  recMove!(0, a, b);
}

