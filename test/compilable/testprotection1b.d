module different_package.a;

import imports.testprotection1;

mixin basic_test_cases!(HasPackageAccess.no);
mixin builtin_property_test_cases!(HasPackageAccess.no);

void test_scope()
{
    mixin scope_test_cases!(HasPackageAccess.no);

    foreach(Scope; ScopeSymbolsTypes)
        with (Scope) mixin scope_test_cases!(HasPackageAccess.no);

    foreach(Scope; ScopeSymbolsExpressions)
        with (Scope) mixin scope_test_cases!(HasPackageAccess.no);
}

void test_templates()
{
    mixin template_test_cases!();
}
