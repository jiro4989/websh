import strformat, strutils
from uri import encodeUrl

import karax / [kbase, vdom, kdom, vstyles, karax, karaxdsl, jdict, jstrutils, jjson, kajax]

type
  ResponseResult = object
    stdout: cstring
    stderr: cstring
    images: seq[cstring]

const
  baseColor = "blue-grey darken-1"
  cardColor = "blue-grey darken-2"
  textColor = "blue-grey-text darken-3"
  apiUrl = "http://localhost/api/shellgei"

var
  inputShell: string
  outputStdout: cstring
  outputStderr: cstring

proc respCb(httpStatus: int, response: cstring) =
  let resp = fromJson[ResponseResult](response)
  echo resp
  outputStdout = resp.stdout

proc createDom(): VNode =
  result = buildHtml(tdiv):
    tdiv(class = &"row {textColor}"):
      nav:
        tdiv(class = &"nav-wrapper {baseColor}"):
          a(class = "brand-logo"): text "シェル芸Web"
      tdiv(class = "col s6"):
        h3: text "Input"
        tdiv(class = "input-field col s12 m6"):
          textarea(id = "inputShell", class = "materialize-textarea"):
            proc onkeyup(ev: Event, n: VNode) =
              inputShell = $n.value
          label(`for` = "inputShell"):
            text "ex: echo 'Hello shell'"
        button(class = "waves-effect waves-light btn"):
          text "実行"
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
            textarea(id = "outputStdout", class = "materialize-textarea", style = style(StyleAttr.minHeight, cstring"400px")):
              text outputStdout
            label(`for` = "outputStdout"):
              text "ex: echo 'Hello shell'"
        # tdiv:
        #   h4: text "Stderr"
        #   tdiv(class = "input-field col s12"):
        #     textarea(id = "outputStderr", class = "materialize-textarea"):
        #       text outputStderr
        #     label(`for` = "outputStderr"):
        #       text "ex: echo 'Hello shell'"
        tdiv:
          h4: text "Images"
    footer(class = &"page-footer {baseColor}"):
      tdiv(class = "footer-copyright"):
        tdiv(class = "container"):
          text "© 2019 jiro4989, "
          a(href = "https://github.com/jiro4989/shellgei_web"): text "Repository"
          text ", MIT License"

setRenderer createDom
