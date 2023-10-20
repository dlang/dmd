// https://issues.dlang.org/show_bug.cgi?id=22927

struct block *tmp;
struct block {};
void block(void);
void block(void){}
