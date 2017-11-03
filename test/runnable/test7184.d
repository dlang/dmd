// Tests for 7184

void main() {
    auto a = 0;
    auto b = (a)++;
    assert(a == 1);
    assert(b == 0);
}
