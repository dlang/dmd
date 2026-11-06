// EXTRA_FILES: imports/ctfe_untaken_branch.d

// A body is analyzed when CTFE first calls it, so a branch that is never taken is never checked

import imports.ctfe_untaken_branch;

enum N = f(true);
int f(bool b) { return b ? 1 : g(); }
int g() { return N; }

int h(bool b) { return b ? 1 : broken(); }
static assert(h(true) == 1);
