module symbol_visibility_provider;

import core.attribute : hidden;

extern(C):
@hidden int hiddenExternal() { return 1; }
int ordinaryExternal() { return 2; }
