module imports.test2225;

class Outer
{
    int a;
private:
    class Inner
    {
        void foo()
        {
            return a;
        }
    }
}
