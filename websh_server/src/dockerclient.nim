import httpclient, json, strformat, streams, endians
from strutils import join

import status

type
  DockerClient = ref object
    client: HttpClient
    url: string
  Mount = object
    Target, Source, Type: string
    ReadOnly: bool

proc newClient*(): DockerClient =
  let
    client = newHttpClient()
    url = "http://localhost:2376"
  return DockerClient(client: client, url: url)

proc createContainer*(self: DockerClient, name: string, image: string, cmds: seq[string], script = "", mediaDir = "", imageDir = ""): Response =
  var self = self
  self.client.headers = newHttpHeaders({ "Content-Type": "application/json" })
  let url = &"{self.url}/containers/create?name={name}"

  var body = %*{
    "Image": image,
    "Cmd": cmds,
    "Tty": false,
  }

  var mounts: seq[Mount]
  if script != "":
    mounts.add(Mount(Target: "/tmp/exec.sh", Source: script, Type: "bind", ReadOnly: true))
  if mediaDir != "":
    mounts.add(Mount(Target: "/media", Source: mediaDir, Type: "bind", ReadOnly: true))
  if imageDir != "":
    mounts.add(Mount(Target: "/images", Source: imageDir, Type: "bind", ReadOnly: false))

  if 1 <= mounts.len:
    body["Mounts"] = % mounts

  self.client.post(url = url, body = $body)

proc startContainer*(self: DockerClient, name: string): Response =
  var self = self
  self.client.headers = newHttpHeaders({ "Content-Type": "application/json" })
  let url = &"{self.url}/containers/{name}/start"
  self.client.post(url = url)

proc killContainer*(self: DockerClient, name: string): Response =
  var self = self
  let url = &"{self.url}/containers/{name}/kill"
  self.client.post(url = url)

proc removeContainer*(self: DockerClient, name: string): Response =
  var self = self
  let url = &"{self.url}/containers/{name}?v=true&force=true"
  self.client.delete(url = url)

proc parseLog(s: string): string =
  var strm = newStringStream(s)
  defer: strm.close
  var lines: seq[string]
  while not strm.atEnd:
    # 1 = stdout, 2 = stderr
    if strm.readUint8() notin [1'u8, 2]:
      break

    # 3byteは使わないので捨てる
    discard strm.readUint8()
    discard strm.readUint8()
    discard strm.readUint8()

    # Bigendianで読み取る
    var src = strm.readUint32().int
    var n: int
    bigEndian32(addr(n), addr(src))

    lines.add(strm.readStr(n))
  result = lines.join

proc getLog(self: DockerClient, name: string, stdout = false, stderr = false): Response =
  let url = &"{self.url}/containers/{name}/logs?stdout={stdout}&stderr={stderr}&follow=true"
  self.client.get(url = url)

proc getStdoutLog*(self: DockerClient, name: string): Response =
  self.getLog(name = name, stdout = true, stderr = false)

proc getStderrLog*(self: DockerClient, name: string): Response =
  self.getLog(name = name, stdout = false, stderr = true)

proc runContainer*(self: DockerClient, name: string, image: string, cmds: seq[string], script = "", mediaDir = "", imageDir = ""): (string, string, int, string) =
  var resp: Response
  resp = self.createContainer(name = name, image = image, cmds = cmds, script = script, mediaDir = mediaDir, imageDir = imageDir)
  if not resp.code.is2xx:
    return ("", "", statusSystemError, &"failed to call 'createContainer': cmds={cmds} resp.body={resp.body}")

  resp = self.startContainer(name = name)
  if not resp.code.is2xx:
    return ("", "", statusSystemError, &"failed to call 'startContainer': cmds={cmds} resp.body={resp.body}")

  var stdoutStr: string
  resp = self.getStdoutLog(name = name)
  if not resp.code.is2xx:
    return ("", "", statusSystemError, &"failed to call 'getStdoutLog': cmds={cmds} resp.body={resp.body}")
  stdoutStr = resp.body.parseLog

  var stderrStr: string
  resp = self.getStderrLog(name = name)
  if not resp.code.is2xx:
    return ("", "", statusSystemError, &"failed to call 'getStderrLog': cmds={cmds} resp.body={resp.body}")
  stderrStr = resp.body.parseLog

  discard self.killContainer(name = name)

  return (stdoutStr, stderrStr, statusOk, "")
