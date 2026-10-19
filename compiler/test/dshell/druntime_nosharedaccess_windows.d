import dshell;

int main()
{
    const src = buildPath("..", "..", "druntime", "src");
    foreach (model; ["32", "64"])
    {
        // Compile the modules as roots to check all Windows function bodies.
        run([DMD, "-conf=", "-I=" ~ src, "-c", "-o-", "-os=windows",
             "-m" ~ model, "-preview=nosharedaccess", "-unittest",
             "-version=CoreUnittest", "-preview=dip1000", "-preview=fieldwise",
             "-preview=dtorfields",
             buildPath(src, "core", "sync", "condition.d"),
             buildPath(src, "rt", "sections_win64.d")]);
    }
    return 0;
}
