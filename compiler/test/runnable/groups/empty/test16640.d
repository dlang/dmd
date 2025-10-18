void testFileFullPathAsDefaultArgument(string preBakedFileFullPath, string fileFullPath = __FILE_FULL_PATH__)
{
    assert(preBakedFileFullPath == fileFullPath);
}

shared static this()
{
    testFileFullPathAsDefaultArgument(__FILE_FULL_PATH__);
}
