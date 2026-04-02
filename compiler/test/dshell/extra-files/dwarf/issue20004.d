enum Color { red, green, blue }
enum Small : ubyte { a = 10, b = 20 }
enum Big : ulong { x = 1, y = 1000000 }
void main() {
    Color c = Color.red;
    Small s = Small.a;
    Big b = Big.y;
}
