import std/streams
import std/osproc
import std/strformat

import ./status

proc readStream(strm: var Stream): string =
  defer: strm.close()
  result = strm.readAll()

proc runCommand(command: string, args: openArray[string], timeout: int): (
    string, string, int, string, string) =
  ## ``command`` を実行し、標準出力と標準エラー出力を返す。
  ## timeout は秒を指定する。
  var
    p = startProcess(command, args = args, options = {poUsePath})
    stdoutStr, stderrStr: string
  defer: p.close()

  let
    timeoutMilSec = timeout * 1000
    exitCode = waitForExit(p, timeout = timeoutMilSec)

  # 処理結果の判定
  let (status, msg, logLevel) = exitCodeToStatus(exitCode, timeout, command, args)

  # 出力の取得
  block:
    var strm = p.outputStream
    stdoutStr = strm.readStream()
  block:
    var strm = p.errorStream
    stderrStr = strm.readStream()

  result = (stdoutStr, stderrStr, status, msg, logLevel)

proc runCommandOnContainer*(imageName, id, hostShellScriptPath, hostImageDir,
    hostMediaDir: string, timeout: int): (string, string, int, string, string) =
  const vScript = "/tmp/script.sh"
  let args = [
    "run",
    "--rm",
    "--net=none",
    "-m", "256MB",
    "--oom-kill-disable",
    "--pids-limit", "1024",
    "--name", id,
    "--log-driver=json-file",
    "--log-opt", "max-size=100m",
    "--log-opt", "max-file=3",
    "-v", &"{hostShellScriptPath}:{vScript}:ro",
    "-v", &"{hostImageDir}:/images",
    "-v", &"{hostMediaDir}:/media:ro",
    imageName,
    "bash", "-c", &"sync && cp {vScript} {vScript}.1 && chmod +x {vScript}.1 && {vScript}.1 | stdbuf -o0 head -c 100K",
    ]
  result = runCommand("docker", args, timeout)
