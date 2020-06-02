import unittest, httpclient, streams, endians, os

include dockerclient

suite "proc newClient":
  test "normal":
    let got = newClient()
    check got.url == "http://localhost:2376"

suite "proc createContainer":
  test "Http 2xx":
    const name = "test_1"
    let client = newClient()
    defer:
      var resp = client.removeContainer(name = name)
      check Http204 == resp.code
    var resp2 = client.createContainer(name = name, image = "bash", cmds = @["echo", "hello"])
    check Http201 == resp2.code

suite "proc startContainer":
  test "Http 2xx":
    const name = "test_1"
    let client = newClient()
    defer:
      var resp = client.removeContainer(name = name)
      check Http204 == resp.code
    var resp2 = client.createContainer(name = name, image = "bash", cmds = @["echo", "hello"])
    check Http201 == resp2.code
    var resp3 = client.startContainer(name = name)
    check Http204 == resp3.code
    sleep 2000

suite "proc getStdoutLog":
  test "Http 2xx":
    const name = "test_1"
    let client = newClient()
    defer:
      var resp = client.removeContainer(name = name)
      check Http204 == resp.code
    var resp2 = client.createContainer(name = name, image = "bash", cmds = @["echo", "hello\nhello2\nhello3"])
    check Http201 == resp2.code
    var resp3 = client.startContainer(name = name)
    check Http204 == resp3.code
    var resp4 = client.getStdoutLog(name = name)
    var body = resp4.body
    var strm = newStringStream(body)
    check 1'u8 == strm.readUint8()
    check 0'u32 == strm.readUint8()
    check 0'u32 == strm.readUint8()
    check 0'u32 == strm.readUint8()
    var src = strm.readUint32()
    var dst: uint32
    bigEndian32(addr(dst), addr(src))
    check 6'u32 == dst
    strm.close
    check Http200 == resp4.code
    var resp5 = client.getStderrLog(name = name)
    check Http200 == resp5.code
    check "" == resp5.body

suite "proc getStderrLog":
  test "Http 2xx":
    const name = "test_1"
    let client = newClient()
    defer:
      var resp = client.removeContainer(name = name)
      check Http204 == resp.code
    var resp2 = client.createContainer(name = name, image = "bash", cmds = @["x"])
    check Http201 == resp2.code
    var resp3 = client.startContainer(name = name)
    check Http204 == resp3.code
    var resp4 = client.getStdoutLog(name = name)
    check Http200 == resp4.code
    check "" == resp4.body
    var resp5 = client.getStderrLog(name = name)
    check Http200 == resp5.code
    check "" != resp5.body

suite "proc runContainer":
  test "Http 2xx":
    const name = "test_1"
    let client = newClient()
    defer:
      var resp = client.removeContainer(name = name)
      check Http204 == resp.code

    let (so, se, n, msg) = client.runContainer(name = name, image = "bash", cmds = @["echo", "hello"])
    check "hello\n" == so
    check "" == se
    check statusOk == n
    check "" == msg
