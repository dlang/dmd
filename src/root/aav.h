
typedef void* Value;
typedef void* Key;

struct AA;

size_t _aaLen(AA* aa);
Value* _aaGet(AA** aa, Key key);
Value _aaGetRvalue(AA* aa, Key key);
void _aaRehash(AA** paa);

