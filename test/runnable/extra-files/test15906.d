import std15906.algo;
import std15906.file;

void main()
{
    [ `` ].map!(a => dirEntries(a).map!(a => a));
}
