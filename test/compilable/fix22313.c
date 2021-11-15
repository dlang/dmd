// https://issues.dlang.org/show_bug.cgi?id=22313

typedef int Integer;
int castint(int x){
    Integer a = (Integer)(x); // cast.c(4)
    Integer b = (Integer)(4); // cast.c(5)
    Integer c = (Integer)x;
    Integer d = (Integer)4;
    Integer e = (int)(x); // cast.c(8)
    int f = (Integer)x;
    Integer g = (int)x;
    Integer h = (int)(4); // cast.c(11)
    Integer i = (int)4;
    int j = (Integer)(x);
    return x;
}

