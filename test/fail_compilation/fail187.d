// REQUIRED_ARGS: -d
// On DMD 2.000 bug only with typedef, not alias

typedef Exception A;
typedef Exception B;

void main() {
  try {
    throw new A("test");
  }
  catch (B) {
    // this shouldn't happen, but does
  }
  catch (A) {
    // this ought to happen?
  }
}

