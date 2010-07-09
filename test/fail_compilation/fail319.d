void f(T...)() if (T.length > 20){}
void main(){
    f!(int, int)();
}

