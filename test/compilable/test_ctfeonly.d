// PERMUTE_ARGS:
// REQUIRED_ARGS:
// POST_SCRIPT: compilable/extra-files/ctfeonly-postscript.sh
// I guess the platforms below don't have nm
// DISABLED: win32 win64 osx


string ctfeOnly(string x, string y)
{
    assert(__ctfe);
    return (x ~ " " ~ y);
}
string ctfeOnlyIn(string x, string y)
in {
    assert(__ctfe);
}
do
{
    return (x ~ " " ~ y);
}
