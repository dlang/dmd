module main;

public void bar() {

}

void main() {
        foreach(Object o ; bar()){
                debug Object foo = null; //error
        }
}

