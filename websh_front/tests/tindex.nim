import unittest

include index

suite "proc countWord":
  test "alphabet only":
    check countWord("hello") == 5
    check countWord("hello\n") == 6
  test "multibyte only":
    check countWord("あいうえお") == 10
    check countWord("漢字") == 4
  test "both":
    check countWord("シェル芸bot") == 11
