// COMPILE_SEPARATELY
// EXTRA_SOURCES: imports/link8072b.d
// DISABLED: http://d.puremagic.com/issues/show_bug.cgi?id=8072

import imports.link8072b;

private void t(alias Code)()
{
  return Code();
}

void f()
{
  t!( () { } )();
}

bool forceSemantic8072()
{
  f();
  return true;
}
static assert(forceSemantic8072());

void main() {
  f();
}
