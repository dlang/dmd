module same_package.a;

import imports.testprotection1;

mixin basic_test_cases!(HasPackageAccess.yes);
mixin builtin_property_test_cases!(HasPackageAccess.yes);

void test_scope()
{
    mixin scope_test_cases!(HasPackageAccess.yes);

    foreach(Scope; ScopeSymbolsTypes)
        with (Scope) mixin scope_test_cases!(HasPackageAccess.yes);

    foreach(Scope; ScopeSymbolsExpressions)
        with (Scope) mixin scope_test_cases!(HasPackageAccess.yes);
}

void test_templates()
{
    mixin template_test_cases!();
}
