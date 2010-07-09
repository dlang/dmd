struct Move{
    int Dx;
}
template genMove(){
    enum Move genMove = { Dx:4 };
}
enum Move b = genMove!();
