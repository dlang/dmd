/*
REQUIRED_ARGS: -vtemplates
TEST_OUTPUT:
---
  Number   Unique   Name

template(s) `A(T)`, `B(T)`, `C(T)`, `D(T)`, `E(T)`, `F(T)`, `G(T)`, `H(T)`, `I(T)`,
`J(T)`, `K(T)`, `L(T)`, `M(T)`, `N(T...)`, `O(T...)`, `P(T...)`, `Q(T...)`, `R(T...)`,
`S(T...)`, `T(T...)`, `U(T...)`, `V(T...)`, `W(T...)`, `X(T...)`, `Y(T...)`, `Z(T...)`,
are excluded because their instantiation follows an optimized path
---
*/
module b21149;

static foreach (immutable(char) c; "ABCDEFGHIJKLM")
{
    mixin ("alias ", c, "(T) = T;");
    mixin ("alias ", c, c, " = ", c, "!int;");
    mixin ("alias ", c, c, "1 = ", c, "!int;");
}

static foreach (immutable(char) c; "NOPQRSTUVWXYZ")
{
    mixin ("alias ", c, "(T...) = T;");
    mixin ("enum ", c, c, " = ", c, "!(0,1);");
    mixin ("enum ", c, c, "1 = ", c, "!(0,1);");
}

int main(){return 0;}
