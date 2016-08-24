module test16423lib;

enum classFqn = __MODULE__ ~ '.' ~ Class.stringof;

void testFromLibrary()
{
    testTypeid();
    testFindingClassInfoFromLibrary();
}

private:

class Class {}

void testTypeid()
{
    auto c = new Class;
    assert(typeid(c) !is null, "typeid not working properly");
}

void testFindingClassInfoFromLibrary()
{
    auto classInfo = ClassInfo.find(classFqn);
    assert(classInfo !is null, "could not find class info for '" ~ classFqn ~
         "' from library");
}
