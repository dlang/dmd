import core.runtime;

void main(string[] args)
{
    dmd_coverDestPath(args[1]);
    enum CHANGE_VAR = 0;
    dmd_coverSetMerge(true);
}
