/*
ARG_SETS: -revert=?
ARG_SETS: -revert=h
TEST_OUTPUT:
----
Revertable language changes listed by -revert=name:
  =all              Enables all available revertable language changes
  =dip25            revert DIP25 changes https://github.com/dlang/DIPs/blob/master/DIPs/archive/DIP25.md
  =intpromote       revert integral promotions for unary + - ~ operators
  =markdown         disable Markdown replacements in Ddoc
  =dtorfields       don't destruct fields of partially constructed objects
----
*/
