import strformat, strutils
from uri import encodeUrl

import karax / [kbase, vdom, kdom, vstyles, karax, karaxdsl, jdict, jstrutils, jjson, kajax]

type
  ResponseResult = object
    result: cstring

const
  baseColor = "blue-grey darken-1"
  cardColor = "blue-grey darken-2"
  textColor = "blue-grey-text darken-3"
  apiUrl = "http://localhost/api/shellgei"

var
  inputShellValue: string
  outputStdoutValue: cstring
  outputStderrValue: cstring

proc respCb(httpStatus: int, response: cstring) =
  let resp = fromJson[ResponseResult](response)
  outputStdoutValue = resp.result

proc createDomTest(): VNode =
  result = buildHtml(tdiv):
    textarea:
      proc onkeyup(ev: Event, n: VNode) =
        echo $n.value
        inputShellValue = $n.value
    button:
      text "実行"
      proc onclick(ev: Event, n: VNode) =
        let body = %*{"code": inputShellValue}
        ajaxPost(apiUrl,
          headers = @[
            (cstring"mode", cstring"cors"),
            (cstring"cache", cstring"no-cache"),
            ],
          data = body.toJson,
          cont = respCb)
    text inputShellValue
    text outputStdoutValue

proc createDom(): VNode =
  result = buildHtml(tdiv):
    tdiv(class = &"row {textColor}"):
      tdiv(class = "col s6"):
        h3: text "Input"
        tdiv(class = "input-field col s12"):
          textarea(id = "inputShell", class = "materialize-textarea"):
            proc onkeyup(ev: Event, n: VNode) =
              inputShellValue = $n.value
          label(`for` = "inputShell"):
            text "ex: echo 'Hello shell'"
        button(class = "waves-effect waves-light btn"):
          text "実行"
          proc onclick(ev: Event, n: VNode) =
            let body = %*{"code": inputShellValue}
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
            textarea(id = "outputStdout", class = "materialize-textarea"):
              text outputStdoutValue
            label(`for` = "outputStdout"):
              text "ex: echo 'Hello shell'"
        tdiv:
          h4: text "Stderr"
          tdiv(class = "input-field col s12"):
            textarea(id = "outputStderr", class = "materialize-textarea"):
              text outputStderrValue
            label(`for` = "outputStderr"):
              text "ex: echo 'Hello shell'"
        tdiv:
          h4: text "Images"
    footer(class = &"page-footer {baseColor}"):
      tdiv(class = "footer-copyright"):
        tdiv(class = "container"):
          text "© 2019 jiro4989, "
          a(href = "https://github.com/jiro4989/shellgei_web"): text "Repository"
          text ", MIT License"

setRenderer createDom
