/* bug581 mtype.c
bug.d(173): Error: template identifier a is not a member of module bug
Error: no property 'b' for type 'int'

// Other errors in this report:  constfold.c
Error: cannot cast int to char[]
// todt.c
Error: non-constant expression cast(char[])0

*/
static assert(.a!().b);
