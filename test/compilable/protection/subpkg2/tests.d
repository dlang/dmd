module protection.subpkg2.tests;

import pkg = protection.subpkg.explicit;

static assert ( is(typeof(pkg.commonAncestorFoo())));
static assert (!is(typeof(pkg.samePkgFoo())));
static assert ( is(typeof(pkg.differentSubPkgFoo())));
static assert (!is(typeof(pkg.unknownPkgFoo())));
