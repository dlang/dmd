alias void delegate() dg;
void fun(){}
void gun(){

  dg d=cast(void delegate())&fun;
}
