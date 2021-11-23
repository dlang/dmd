/+
https://issues.dlang.org/show_bug.cgi?id=22540
TEST_OUTPUT:
---
Value:
double: double* => null
int: int* => null
char: char* => null

Explicit but identical:

Explicit not null:
double: double* => cast(double*)1$?:32=u|64=LU$
int: int* => cast(int*)1$?:32=u|64=LU$
char: char* => cast(char*)1$?:32=u|64=LU$

Arrays:
int: int[][][] => [[[0]]]
string: string[][][] => [[[null]]]
double: double[][][] => [[[1.0]]]

Alias:
double: double* => null
int: int* => null
char: char* => null

Explicit but identical:

Explicit not null:
double: double* => cast(double*)1$?:32=u|64=LU$
int: int* => cast(int*)1$?:32=u|64=LU$
char: char* => cast(char*)1$?:32=u|64=LU$
---
+/


pragma(msg, "\nValue:");

template Value(T = int, T* ptr = (T*).init)
{
    pragma(msg, T, ": ", typeof(ptr), " => ", ptr);
}

alias v1 = Value!(double);
alias v2 = Value!(int);
alias v3 = Value!(char);

pragma(msg, "\nExplicit but identical:");

alias v1n = Value!(double, null);
alias v2n = Value!(int, null);
alias v3n = Value!(char, null);

pragma(msg, "\nExplicit not null:");

enum double* dv = cast(double*) 1;
enum int* iv = cast(int*) 1;
enum char* cv = cast(char*) 1;

alias v4 = Value!(double, dv);
alias v5 = Value!(int, iv);
alias v6 = Value!(char, cv);

pragma(msg, "\nArrays:");

template Arrays(T = int, T[][][] ptr = [[[ T.init ]]])
{
    pragma(msg, T, ": ", typeof(ptr), " => ", ptr);
}

alias b1 = Arrays!();
alias b2 = Arrays!(string);
alias b3 = Arrays!(double, [[[ 1.0 ]]]);

pragma(msg, "\nAlias:");

template Alias(T = int, alias T* ptr = (T*).init)
{
    pragma(msg, T, ": ", typeof(ptr), " => ", ptr);
}

alias a1 = Alias!(double);
alias a2 = Alias!(int);
alias a3 = Alias!(char);

pragma(msg, "\nExplicit but identical:");

alias a1n = Alias!(double, cast(double*) null); // Explicit cast because exact match is required instead of TypeNull
alias a2n = Alias!(int, cast(int*) null);
alias a3n = Alias!(char, cast(char*) null);

pragma(msg, "\nExplicit not null:");

alias a4 = Alias!(double, dv);
alias a5 = Alias!(int, iv);
alias a6 = Alias!(char, cv);
