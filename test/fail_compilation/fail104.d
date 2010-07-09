// 76
// Compiling leads to "Assertion failure: 's->parent' on line 1694 in file
// 'template.c'"

struct S
{
        template T()
        {
                void x(int i)
                {                       
                }
        }
}

class C(P)
{
        mixin P!().T!();
}

int main(char[][] args)
{
        auto c = new C!(S);

        return 0;
}

