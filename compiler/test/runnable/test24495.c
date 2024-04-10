struct Subitem {
    int x;
    int y;
};

struct Item {

    int a;

    struct {
        int b1;
        struct Subitem b2;
        int b3;
    };

};

int main() {

    struct Item first = {
        .a = 1,
        .b1 = 2,
        .b3 = 3,
    };
    struct Item second = {
        .a = 1,
        {
            .b1 = 2,
            .b2 = { 1, 2 },
            .b3 = 3
        }
    };

    return second.a != 1
        || second.b1 != 2
        || second.b2.x != 1
        || second.b2.y != 2
        || second.b3 != 3;

}
