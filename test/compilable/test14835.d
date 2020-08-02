//REQUIRED_ARGS: -w
template naiveAllInts(T...)
{
    auto fun()
    {
        static foreach(U; T)
        {
            static if (is(U : int))
                return false;
        }
        return true;
    }
    alias naiveAllInts = fun;
}

alias string = immutable(char)[];
enum b = naiveAllInts!(float, string);
enum a = naiveAllInts!(int,string);
