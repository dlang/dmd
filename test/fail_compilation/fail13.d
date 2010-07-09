template Tocka()
{
 int x=2,y=7;
 void print(){printf("x = %d y = %d\n",x,y);}
}

class Line
{
 mixin Tocka T1;
 mixin Tocka T2;

 void play()
 {
  T1.print();
  T2.print();
  printf("\n");
  T1.x = 100;
  T1.y = 50;
  T2.x = 25;
  T2.y = 5;
  T1.print();
  T2.print();
  printf("T1.x = %d T1.y = %d\n",T1.x,T1.y);
  printf("T2.x = %d T2.y = %d\n",T2.x,T2.y);
 }
}

int main(char[][] args)
{
 Line T = new Line();
 T.play();
 return 1;
}

