void main() {
    foreach (i; 0 .. 2)
    {
        foreach(inout char x; "hola") {
	    printf("%c", x);
	    x = '?';
        }
    }
}

