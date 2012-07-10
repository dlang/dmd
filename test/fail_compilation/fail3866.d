
void main() {

    auto foo = (int a = 1) { return a;};
    auto bar = (int a) { return a;};

    foo();
    bar();
}

