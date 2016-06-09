// PERMUTE_ARGS: -w -wi

version(D_Warnings)
{
    // Good
}
else
{
    static assert (0, "Missing 'D_Warnings' version identifier");
}
