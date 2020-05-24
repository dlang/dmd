module issue15818;

void f(int) @system;
void f(int) @system;
void f(int) @system;
void f(int) @system;
void f(int) @system;

pragma(mangle, "_D10issue158181fFiZv")
void theVeritableF(int){}

void main()
{
    f(1);
}
