/+ TEST_OUTPUT:
---
fail_compilation/throwexp.d(15): Error: to be thrown `ret()` must be non-null
enum y = throw ret();
                  ^
fail_compilation/throwexp.d(16): Error: to be thrown `null` must be non-null
enum x = throw Exception.init;
               ^
---
+/
auto ret()
{
    return Exception.init;
}
enum y = throw ret();
enum x = throw Exception.init;
