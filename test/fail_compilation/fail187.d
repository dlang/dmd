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

