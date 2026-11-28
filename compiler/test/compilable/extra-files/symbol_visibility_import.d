module symbol_visibility_import;

import core.attribute : hidden;

extern(C):
@hidden int hiddenExternal();
int ordinaryExternal();
