// [25]

template crash(T) {
        void crash(T t) {
                foreach(u;t) {}
        }
}

void main() {
        crash(null);
}

