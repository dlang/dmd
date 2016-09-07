import test16423lib;

void testFindingClassInfoFromExecutable()
{
    auto classInfo = ClassInfo.find(classFqn);
    assert(classInfo !is null, "could not find class info for '" ~ classFqn ~
         "' from executable");
}

void testFromExecutable()
{
    testFindingClassInfoFromExecutable();
}

void main()
{
    testFromLibrary();
    testFromExecutable();
}
