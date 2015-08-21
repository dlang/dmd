import core.runtime;

void main(string[] args)
{
    dmd_coverDestPath(args[1]);
    dmd_coverSetMerge(true);
}
