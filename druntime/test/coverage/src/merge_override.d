import core.runtime;

void main(string[] args)
{
    dmd_coverDestPath(args[1]);
    dmd_coverSourcePath(args[2]);
    enum CHANGE_VAR = 0;
    dmd_coverSetMerge(true);
}
