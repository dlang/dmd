module symbol_visibility;

import core.attribute : hidden;
import symbol_visibility_import : hiddenExternal, ordinaryExternal;

extern(C):
int ordinaryFunction() { return 1; }
export int exportedFunction() { return 2; }
@hidden int hiddenFunction() { return 3; }
@hidden export int hiddenExportedFunction() { return 4; }
__gshared int ordinaryData = 1;
export __gshared int exportedData = 2;
@hidden __gshared int hiddenData = 3;
@hidden export __gshared int hiddenExportedData = 4;
__gshared int ordinaryBSS;
export __gshared int exportedBSS;
@hidden __gshared int hiddenBSS;
int ordinaryTLS;
export int exportedTLS;
@hidden int hiddenTLS;
struct Other { enum hidden; }
@(Other.hidden) int ordinaryHiddenName() { return 8; }

int callExternal() { return hiddenExternal() + ordinaryExternal(); }

@hidden {
    int blockHidden() { return 5; }
}

// Nested UDA scopes and aliases must not obscure @hidden.
enum unrelated;
alias attributes = AliasSeq!(hidden, unrelated);
template AliasSeq(T...) { alias AliasSeq = T; }
@unrelated @attributes int tupleHidden() { return 6; }

extern(D):
T ordinaryTemplate(T)(T value) { return value; }
@hidden T hiddenTemplate(T)(T value) { return value; }
int instantiate() { return ordinaryTemplate(1) + hiddenTemplate(2); }

@hidden:
extern(C) int colonHidden() { return 7; }
