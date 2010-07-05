// COMPILE_SEPARATELY
// EXTRA_SOURCES: imports/test55a.d
// PERMUTE_ARGS:

public import imports.test55a;

class Queue {
  typedef int ListHead;
  Arm a;
}

class MessageQueue : Queue {
}

class Queue2 {
  typedef int ListHead;
  Arm2 a;
}

