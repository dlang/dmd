
class A
{
 class B:A
 {
   const int C = 5;
 }
}

void main()
{
    printf ("1 %d\n", A.B.C);
    printf ("2 %d\n", A.B.B.C);
    printf ("3 %d\n", A.B.B.B.C);
}
