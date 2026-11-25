module protection.subpkg2.tests;

import pkg = protection.subpkg.explicit;

static assert (is(typeof(pkg.commonAncestorFoo())));

import pkgmod = protection.subpkg;

static assert (!is(typeof(pkgmod.packageModFoo())));
