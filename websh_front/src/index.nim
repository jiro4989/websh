import strformat, strutils
from uri import encodeUrl

import karax / [kbase, vdom, kdom, vstyles, karax, karaxdsl, jdict, jstrutils, jjson, kajax]

type
  ResponseResult = object
    stdout: cstring
    stderr: cstring
    images: seq[cstring]

const
  baseColor = "grey darken-4"
  textColor = "green-text darken-3"
  textInputColor = "grey-text lighten-5"

when defined local:
  # ローカル開発用
  const apiUrl = "http://localhost/api/shellgei"
else:
  # 本番用
  const apiUrl = "https://websh.jiro4989.com/api/shellgei"

var
  inputShell = cstring""
  outputStdout = cstring""
  outputStderr = cstring""
  outputImages: seq[cstring]

proc respCb(httpStatus: int, response: cstring) =
  let resp = fromJson[ResponseResult](response)
  outputStdout = resp.stdout
  outputStderr = resp.stderr
  outputImages = resp.images

proc createDom(): VNode =
  result = buildHtml(tdiv):
    tdiv(class = &"row {baseColor} {textColor}"):
      nav:
        tdiv(class = &"nav-wrapper {baseColor}"):
          a(class = &"brand-logo {textColor}"): text "websh"
      tdiv(class = "col s6"):
        h3: text "Input"
        tdiv(class = "input-field col s12 m6"):
          textarea(id = "inputShell", class = &"materialize-textarea {textInputColor}", setFocus = true):
            proc onkeyup(ev: Event, n: VNode) =
              inputShell = $n.value
          label(`for` = "inputShell"):
            text "ex: echo 'Hello shell'"
        button:
          text "Run"
          proc onclick(ev: Event, n: VNode) =
            let body = %*{"code": inputShell}
            ajaxPost(apiUrl,
              headers = @[
                (cstring"mode", cstring"cors"),
                (cstring"cache", cstring"no-cache"),
                ],
              data = body.toJson,
              cont = respCb)
      tdiv(class = "col s6"):
        h3: text "Output"
        tdiv:
          h4: text "Stdout"
          tdiv(class = "input-field col s12"):
            textarea(id = "outputStdout", class = &"materialize-textarea {textInputColor}", style = style(StyleAttr.minHeight, cstring"200px")):
              text outputStdout
        tdiv:
          h4: text "Stderr"
          tdiv(class = "input-field col s12"):
            textarea(id = "outputStderr", class = &"materialize-textarea {textInputColor}", style = style(StyleAttr.minHeight, cstring"200px")):
              text outputStderr
        tdiv:
          h4: text "Images"
          for img in outputImages:
            tdiv:
              img(src = img)
    footer(class = &"page-footer {baseColor}"):
      tdiv(class = "footer-copyright"):
        tdiv(class = "container"):
          text "© 2019 jiro4989, "
          a(href = "https://github.com/jiro4989/websh"): text "Repository"
          text ", MIT License"

setRenderer createDom
