#include <exception>

void throw_exception()
{
    throw std::exception();
}

void throw_bad_exception()
{
    throw std::bad_exception();
}

class custom_exception : public std::exception
{
    const char* what() const noexcept { return "custom_exception"; }
};

void throw_custom_exception()
{
    throw custom_exception();
}
