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
    foreach (i; f.oldIterMix.Iter) {  }
}
