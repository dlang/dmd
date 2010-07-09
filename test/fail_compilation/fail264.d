void main() {
    foreach (element; undef) {
        fn(element);
    }
}

void fn(int i) {}

