# Basic Type __totype

The following construct is added as a BasicType:

---
TotypeType:
    __totype ( AssignExpression )
---

AssignExpression is evaluated at compile time, and the result must be
a string. The string must be a sequence of characters representing the
mangling of an existing type. The TotypeType is then that type.

For example:

---
pragma(msg, 1.mangleof); // prints `i`
__totype("i") x;         // declares `x` as having type `int`
__totype("Pi") p;        // declares `p` as having type `int*`
__totype(3) y;           // error: `3` is not a string
__totype("#Hello") z;    // error: `#Hello` is not a recognized mangling of a type
---
