// 153

template bar(T) {
    void foo() {}
}

alias bar!(long).foo foo;
alias bar!(char).foo foo;


void main() {
    foo!(long);
}

