/*
REQUIRED_ARGS: -vtemplates
TEST_OUTPUT:
---
  Number   Unique   Name
---
*/
module b21149;

alias X(T) = T;
alias Seq(T...) = T;

void foo(X!int p){}

alias Y = X!int;
alias Z = X!int;
alias S = Seq!(0,1);

int main(){return 0;}
