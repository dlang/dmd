// COMPILE_SEPARATELY
// EXTRA_SOURCES: imports/link8023b.d
// PERMUTE_ARGS:

import imports.link8023b;

private void t(alias Code)()
{
  return Code();
}

void f()
{
  t!( () { } )();
}

bool forceSemantic()
{
    f();
    return true;
}

static assert(forceSemantic());

void main() {
  f();
}
