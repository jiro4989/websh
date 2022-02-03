from std/os import getEnv
from std/strutils import parseInt

type
  Config* = object
    hostPwd*: string
    webshPort*: int
    webshRequestTimeout*: int
    webshShellgeiBotImageName*: string

proc loadConfigByEnv*(): Config =
  let hostPwd = getEnv("HOST_PWD")
  doAssert hostPwd != ""
  result.hostPwd = hostPwd

  let port = getEnv("WEBSH_PORT", "5000").parseInt
  result.webshPort = port

  let timeout = getEnv("WEBSH_REQUEST_TIMEOUT", "3").parseInt
  result.webshRequestTimeout = timeout

  let image = getEnv("WEBSH_SHELLGEI_BOT_IMAGE_NAME", "theoldmoon0602/shellgeibot")
  result.webshShellgeiBotImageName = image