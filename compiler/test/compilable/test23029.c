/* https://issues.dlang.org/show_bug.cgi?id=23029
 */

void print_const(const char*);
void print(char*);
int main(){
    (void)_Generic("",
            char*: print,
            const char*: print_const
        )("hello");
}
