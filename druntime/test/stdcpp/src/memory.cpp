#include <memory>

std::unique_ptr<int> passThrough(std::unique_ptr<int> x)
{
    return std::move(x);
}
std::unique_ptr<int> changeIt(std::unique_ptr<int> x)
{
    auto p = new int(20); // ensure new pointer is different from released pointer
    x.reset();
    return std::unique_ptr<int>(p);
}
