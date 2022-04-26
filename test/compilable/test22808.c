// https://issues.dlang.org/show_bug.cgi?id=22808

typedef int(*cmp)(int, int);

int icmp(int a, int b);

cmp getcmp(void){
    cmp c;
    c = icmp;
    c = &icmp;
    if(0)
        return c;
    if(0)
        return &icmp;
    return icmp;
}
