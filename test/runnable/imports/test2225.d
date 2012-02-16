module imports.test2225;

class Outer
{
    int a;

    Inner makeInner()
    {
        return this.new Inner;
    }

private:
    class Inner
    {
        int foo()
        {
            return a;
        }
    }
}
