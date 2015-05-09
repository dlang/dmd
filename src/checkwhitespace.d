
import std.stdio;
import std.file;
import std.string;
import std.range;
import std.regex;
import std.algorithm;
import std.path;

int main(string[] args)
{
    bool error;
    auto r = regex(r" +\n");
    foreach(a; args[1..$])
    {
        auto str = a.readText();
        if (str.canFind("\r\n"))
        {
            writefln("Error - file '%s' contains windows line endings", a);
            error = true;
        }
        if (a.extension() != ".mak" && str.canFind('\t'))
        {
            writefln("Error - file '%s' contains tabs", a);
            error = true;
        }
        if (!str.matchFirst(r).empty)
        {
            writefln("Error - file '%s' contains trailing whitespace", a);
            error = true;
        }
    }
    return error ? 1 : 0;
}
