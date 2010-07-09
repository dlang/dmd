// 441

template opHackedApply() {
    struct Iter {
    }
}

class Foo {
    mixin opHackedApply!() oldIterMix;
}

void main() {
    Foo f = new Foo;
    foreach (int i; f.oldIterMix.Iter) {  }
}
