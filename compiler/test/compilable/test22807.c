// https://issues.dlang.org/show_bug.cgi?id=22807


struct OldFashionedHeader {
    int n; // number of entries in buff
    char buff[1];
};


int peek(OldFashionedHeader *head){
    if(head->n < 2)
        return 0;
    return head->buff[1]; // do not give array bounds error
}
