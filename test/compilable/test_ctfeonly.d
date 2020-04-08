// PERMUTE_ARGS:
// REQUIRED_ARGS: -betterC
// POST_SCRIPT: compilable/extra-files/ctfeonly-postscript.sh
// I guess the platforms below don't have nm
// DISABLED: win32 win64 osx


pragma(ctfe)
string ctfeOnly(string x, string y)
{
    return (x ~ " " ~ y);
}

pragma(ctfe)
string ctfeOnlyIn(string x, string y)
{
    return (x ~ " " ~ y);
}

pragma(ctfe)
string typeinfo(string s)
{
   return typeid(s).stringof ~ s;
}

pragma(ctfe)
string exceptions()
{
    try
    {
        throw new Exception("");
    }
    catch(Exception e) {}
    return "";
}

import core.stdc.stdarg;
pragma(ctfe)
int varargs(char c, ...)
{
    return 0;
}
