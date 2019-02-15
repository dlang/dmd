#include <assert.h>
#include <cstddef>

void testnull(std::nullptr_t n)
{
  assert(n == nullptr);
}

void testnullnull(std::nullptr_t n1, std::nullptr_t n2)
{
  assert(n1 == nullptr);
  assert(n2 == nullptr);
}
