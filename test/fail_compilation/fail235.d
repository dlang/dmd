/*
Error: expression & D10TypeInfo_a6__initZ is not a valid template value argument

a.d(7): template instance a.Tuple!(& D10TypeInfo_a6__initZ) error instantiating
*/
template Tuple(TPL...)
{
    alias TPL Tuple;
}

auto K = Tuple!(typeid(char));
