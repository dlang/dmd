// 289

alias int ft(int);

ft[] x;  // is allowed 

void test() {
    x.length = 2;  // crashes DMD
}
