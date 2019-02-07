module imports.test15371;

//This needs to be in a seperate module to trigger this issue.
public class Test15371 {
    private int privateField;

    private int overload(int param1) { return param1; }
    private int overload(int param1, int param2) { return param2; }

    public this() {
        privateField = 0;
    }
}
