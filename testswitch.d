int func(char _c) {
        foreach(_;0 .. 16) {}
//      char _c = s[1];
        int acc;
        switch(_c) {
        //      a = 22 + 44; // unreachable code;
                case 'a' : return 5;
                case 'd' : goto case 'b';
                case 'b' : return 2; /*+ func(s[1 .. $]);*/
                case 'c' : {
                acc--;{acc++;}{
                        acc++;
                        { goto default; }
                }}
                case 'f' : {
                        goto case 'b';
                }
                case 'e' : break;
                default : return acc; break;

        }

return 16;

}
//static assert(func('c') == 1);
static assert(func('f') == 2);
static assert(func('e') == 16);

