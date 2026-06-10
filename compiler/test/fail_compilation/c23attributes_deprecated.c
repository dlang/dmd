/* REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/c23attributes_deprecated.c(21): Deprecation: function `c23attributes_deprecated.mars` is deprecated
fail_compilation/c23attributes_deprecated.c(15):        `mars` is declared here
fail_compilation/c23attributes_deprecated.c(21): Deprecation: function `c23attributes_deprecated.jupiter` is deprecated - jumping jupiter
fail_compilation/c23attributes_deprecated.c(16):        `jupiter` is declared here
fail_compilation/c23attributes_deprecated.c(21): Deprecation: function `c23attributes_deprecated.saturn` is deprecated - alt spelling
fail_compilation/c23attributes_deprecated.c(17):        `saturn` is declared here
---
*/

// C23 6.7.13.5 the deprecated attribute fires when the entity is used; the __attr__
// spelling (6.7.13.1) behaves identically.
[[deprecated]] int mars(void);
[[deprecated("jumping jupiter")]] int jupiter(void);
[[__deprecated__("alt spelling")]] int saturn(void);

int test(void)
{
    return mars() + jupiter() + saturn();
}
