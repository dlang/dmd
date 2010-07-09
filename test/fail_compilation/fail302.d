
struct Bar {
    uint num;

    Bar opAssign(uint otherNum) {
        num = otherNum;
        return this;
    }
}

void main() {
    Bar bar = 1;	// disallow because construction is not assignment
    auto x = bar.num;
}
