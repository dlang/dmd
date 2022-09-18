#include <typeinfo>

void throw_bad_cast()
{
    throw std::bad_cast();
}

void throw_bad_typeid()
{
    throw std::bad_typeid();
}

const std::type_info& typeid_int()
{
    return typeid(int);
}

const std::type_info& typeid_double()
{
    return typeid(double);
}

class Toil { };

const std::type_info& typeid_toil()
{
    return typeid(Toil);
}

const std::type_info& typeid_const_toil()
{
    return typeid(const Toil&);
}

class Trouble { };

const std::type_info& typeid_trouble()
{
    return typeid(Trouble);
}
