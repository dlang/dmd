import core.stdc.string;
import core.stdcpp.exception;

unittest
{
    try
    {
        throw_exception();
    }
    catch (exception e)
    {
        const what = e.what();
        assert(!strcmp(what, "unknown") || // druntime override
               !strcmp(what, "std::exception"));
    }
    try
    {
        throw_bad_exception();
    }
    catch (exception e)
    {
        const what = e.what();
        assert(!strcmp(what, "bad exception") || // druntime override
               !strcmp(what, "std::bad_exception"));
    }
    try
    {
        throw_custom_exception();
    }
    catch (exception e)
    {
        assert(!strcmp(e.what(), "custom_exception"));
    }
}

extern(C++):
void throw_exception();
void throw_bad_exception();
void throw_custom_exception();
