/* https://issues.dlang.org/show_bug.cgi?id=23025
 */

const char *s; // tentative definition
const char *s = "hello"; // definition
int puts(const char*);
int main(void){
    puts(s);
    return 0;
}
