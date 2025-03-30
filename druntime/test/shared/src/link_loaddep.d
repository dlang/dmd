import libloaddep;

void main(string[] args)
{
    import utils : dllExt;
    auto libname = args[0][0..$-"link_loaddep".length] ~ "lib." ~ dllExt ~ "\0";
    runDepTests(libname.ptr);
}
