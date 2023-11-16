/*
TEST_OUTPUT:
---
fail_compilation/fail217.d(23): Error: mutable constructor `this` cannot construct a `immutable` object
fail_compilation/fail217.d(14):        `fail217.Message.this(int notifier_object)` declared here
fail_compilation/fail217.d(14):        Consider adding `const` or `inout`
---
*/

class Message
  {
    public int notifier;

    this( int notifier_object )
      {
        notifier = notifier_object;
      }
  }

void
main()
  {
    auto m2 = new immutable(Message)(2);
    m2.notifier = 3;
  }
