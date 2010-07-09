/* bug870  [There is another bug in that report] template.c
Error: identifier 'x' is not defined
Error: x is used as a type
bug.d(133): template bug.Templ2(alias a) does not match any template declaratio

bug.d(133): template bug.Templ2(alias a) cannot deduce template function from a
*/

template Templ2(alias a) {
    void Templ2(x) {
    }
  }

  void main() {
    int i;
    Templ2(i);
  }
