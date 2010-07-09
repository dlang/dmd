pure int double_sqr(int x) {
    int y = x;
    void do_sqr() pure { y *= y; }
    do_sqr();
    return y;
}

void main(string[] args) {
   assert(double_sqr(10) == 100);
}
