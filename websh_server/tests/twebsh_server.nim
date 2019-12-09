import unittest

include websh_server

suite "proc runCommand":
  test "echo":
    let (s, e) = runCommand("echo", ["test"])
    check s == "test"
    check e == ""
  test "not found command":
    let (s, e) = runCommand("bash", ["-c", "not_found_command"])
    check s == ""
    check e != ""

