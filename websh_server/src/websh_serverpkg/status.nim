from std/strformat import `&`

const
  statusOk* = 0
  statusTimeout* = 1
  statusSystemError* = 100

func exitCodeToStatus*(exitCode: int, timeout: int, command: string,
    args: openArray[string]): (int, string, string) =
  if exitCode == 0:
    (statusOk, "", "info")
  elif exitCode == 137:
    (statusTimeout, &"timeout: {timeout} second", "error")
  else:
    (statusSystemError, &"failed to run command: command={command}, args={args}", "error")
