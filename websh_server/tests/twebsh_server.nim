import unittest

include websh_server

suite "proc runCommand":
  test "'echo' has carriage return":
    let (s, e, status, msg) = runCommand("echo", ["test"])
    check s == "test\n"
    check e == ""
    check status == statusOk
    check msg == ""
  test "'echo -n' has not carriage return":
    let (s, e, status, msg) = runCommand("echo", ["-n", "test"])
    check s == "test"
    check e == ""
    check status == statusOk
    check msg == ""
  test "stderr":
    let (s, e, status, msg) = runCommand("bash", ["-c", "echo test >&2"])
    check s == ""
    check e == "test\n"
    check status == statusOk
    check msg == ""
  test "not found command":
    let (s, e, status, msg) = runCommand("bash", ["-c", "not_found_command | :"])
    check s == ""
    check e != ""
    check status == statusOk
    check msg == ""
  test "timeout 3 seconds":
    let (s, e, status, msg) = runCommand("bash", ["-c", "sleep 5; echo test"])
    check s == ""
    check e == ""
    check status == statusTimeout
    check msg != ""
