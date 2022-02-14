import core.stdc.string;
import core.stdcpp.typeinfo;

unittest
{
    try
    {
        throw_bad_cast();
    }
    catch (bad_cast e)
    {
        const what = e.what();
        assert(!strcmp(what, "bad cast") || // druntime override
               !strcmp(what, "std::bad_cast"));
    }
    try
    {
        throw_bad_typeid();
    }
    catch (bad_typeid e)
    {
        const what = e.what();
        assert(!strcmp(what, "bad typeid") || // druntime override
               !strcmp(what, "std::bad_typeid"));
    }

    const tid1 = typeid_int();
    const tid2 = typeid_double();
    assert(tid1 != tid2);
    assert(!strcmp(tid1.name(), "i"));
    assert(!strcmp(tid2.name(), "d"));

    const tid3 = typeid_toil();
    const tid4 = typeid_const_toil();
    assert(tid3 == tid4);
    assert(!strcmp(tid3.name(), "4Toil"));

    const tid5 = typeid_trouble();
    assert(tid4 != tid5);
    assert(!strcmp(tid5.name(), "7Trouble"));

    assert(tid2.before(tid1));
    assert(tid3.before(tid2));
    assert(tid4.before(tid5));
}

extern(C++):
void throw_bad_cast();
void throw_bad_typeid();
const(type_info) typeid_int();
const(type_info) typeid_double();
const(type_info) typeid_toil();
const(type_info) typeid_const_toil();
const(type_info) typeid_trouble();
