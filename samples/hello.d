
import std.stdio;

void main(string[] args)
{
    writeln("hello world");
    writefln("args.length = %d", args.length);

    foreach (index, arg; args)
    {
        writefln("args[%d] = '%s'", index, arg);
    }
}
