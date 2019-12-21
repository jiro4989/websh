import unittest

include websh_server

suite "proc runCommand":
  test "echo":
    let (s, e, status, msg) = runCommand("echo", ["test"])
    check s == "test"
    check e == ""
    check status == statusOk
    check msg == ""
  test "not found command":
    let (s, e, status, msg) = runCommand("bash", ["-c", "not_found_command"])
    check s == ""
    check e != ""
    check status == statusOk
    check msg == ""

