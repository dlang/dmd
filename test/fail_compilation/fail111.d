// 289

alias int function (int) ft;

ft[] x;  // is allowed 

void test() {
    x.length = 2;  // crashes DMD
}
