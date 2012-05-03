// COMPILE_SEPARATELY
// EXTRA_SOURCES: imports/link8016b.d
// PERMUTE_ARGS:

import imports.link8016b;

private void t(alias Code)()
{
  return Code();
}

void f()
{
  t!( () { } )();
}

bool forceSemantic8016()
{
  f();
  return true;
}
static assert(forceSemantic8016());

void main() {
  f();
}
