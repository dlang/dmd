
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
        try
        {
            ptrdiff_t pos;
            auto str = a.readText();
            if ((pos = str.indexOf("\r\n")) >= 0)
            {
                writefln("Error - file '%s' contains windows line endings at line %d", a, str[0..pos].count('\n') + 1);
                error = true;
            }
            if (a.extension() != ".mak" && (pos = str.indexOf('\t')) >= 0)
            {
                writefln("Error - file '%s' contains tabs at line %d", a, str[0..pos].count('\n') + 1);
                error = true;
            }
            auto m = str.matchFirst(r);
            if (!m.empty)
            {
                pos = m.front.ptr - str.ptr; // assume the match is a slice of the string
                writefln("Error - file '%s' contains trailing whitespace at line %d", a, str[0..pos].count('\n') + 1);
                error = true;
            }
        }
        catch(Exception e)
        {
            writefln("Exception - file '%s': %s", a, e.msg);
        }
    }
    return error ? 1 : 0;
}
