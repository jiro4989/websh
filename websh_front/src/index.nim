from strutils import split
from strformat import `&`
from unicode import isAlpha, toRunes, runeAt, `==`, `$`
from uri import encodeUrl
from sequtils import mapIt, toSeq

import karax / [kbase, vdom, kdom, vstyles, karax, karaxdsl, jdict, jstrutils, jjson, kajax]

type
  ResponseResult = object
    status: cint
    system_message: cstring
    stdout: cstring
    stderr: cstring
    images: seq[cstring]

const
  baseColor = "grey darken-4"
  textColor = "green-text darken-3"
  textInputColor = "grey-text lighten-5"
  statusOk = cint(0)
  statusTimeout = cint(1)
  statusSystemError = cint(100)

let
  byte1Runes = toSeq(0..255).mapIt(chr(it).`$`.runeAt(0))

when defined local:
  # ローカル開発用
  const apiUrl = "http://localhost/api/shellgei"
else:
  # 本番用
  const apiUrl = "https://websh.jiro4989.com/api/shellgei"

var
  inputShell = cstring""
  outputStatus = cint(0)
  outputSystemMessage = cstring""
  outputStdout = cstring""
  outputStderr = cstring""
  outputImages: seq[cstring]
  isProgress: bool
    ## シェルの実行中表示を切り替えるためのフラグ

proc respCb(httpStatus: int, response: cstring) =
  let resp = fromJson[ResponseResult](response)
  outputStatus = resp.status
  outputSystemMessage = resp.system_message
  outputStdout = resp.stdout
  outputStderr = resp.stderr
  outputImages = resp.images
  # シェルの実行中表示 OFF
  isProgress = false

proc sendShellButtonOnClick(ev: Event, n: VNode) = # シェルの実行中表示 ON
  isProgress = true
  let body = %*{"code": inputShell}
  ajaxPost(apiUrl,
    headers = @[
      (cstring"mode", cstring"cors"),
      (cstring"cache", cstring"no-cache"),
      ],
    data = body.toJson,
    cont = respCb)

proc countWord(s: string): int =
  ## 文字数をカウントする。
  ## アルファベットは1文字、マルチバイト文字は2文字として数える。
  for c in s.toRunes():
    if c in byte1Runes:
      # アルファベットのとき
      inc(result)
    else:
      # それ以外はマルチバイト文字のはず（たぶん）
      inc(result, 2)

proc createDom(): VNode =
  result = buildHtml(tdiv):
    tdiv(class = &"row {baseColor} {textColor}"):
      nav:
        tdiv(class = &"nav-wrapper {baseColor}"):
          a(class = &"brand-logo {textColor}"): text "websh"
      tdiv(class = "col s6"):
        if isProgress:
          tdiv(class = "col s12 m12"):
            text "Running ..."
        if outputStatus != statusOk:
          tdiv(class = "col s12 m12"):
            text outputSystemMessage
        h3: text "Input"
        tdiv(class = "input-field s12 m6"):
          let count = countWord($inputShell)
          tdiv(class = "s12 m6"):
            text &"{$count} chars"
          let remain = 280 - count
          let remainPercent = int(count / 280 * 100)
          let color =
            if 100 <= remainPercent: "red darken-3"
            elif 70 <= remainPercent: "yellow darken-4"
            else: ""
          tdiv(class = &"s12 m6 {color}"):
            text &"Remaining: {$remain} chars ({$remainPercent}%)."
        tdiv(class = "input-field s12 m6"):
          textarea(id = "inputShell", class = &"materialize-textarea {textInputColor}", setFocus = true, style = style(StyleAttr.minHeight, cstring"400px")):
            proc onkeydown(ev: Event, n: VNode) =
              let kbEvt = cast[KeyboardEvent](ev)
              # Ctrl + Enterで実行
              if kbEvt.ctrlKey and kbEvt.keyCode == 13:
                sendShellButtonOnClick(ev, n)
            proc onkeyup(ev: Event, n: VNode) =
              inputShell = $n.value
          label(`for` = "inputShell"):
            text "ex: echo 'Hello shell'"
        button(onclick = sendShellButtonOnClick):
          text "Run (Ctrl + Enter)"
        a(href = &"""https://twitter.com/intent/tweet?button_hashtag=シェル芸&text={encodeUrl($inputShell, false)}&ref_src=twsrc%5Etfw""",
            class = "twitter-share-button",
            `data-show-count` = "false"):
          text "Tweet"
      tdiv(class = "col s6"):
        h3: text "Output"
        tdiv:
          h4: text "Stdout"
          tdiv(class = "s12 m6"):
            text &"{countWord($outputStdout)} chars, "
            text &"""{$($outputStdout).split("\n").len} lines"""
          tdiv(class = "input-field col s12"):
            textarea(id = "outputStdout", class = &"materialize-textarea {textInputColor}", style = style(StyleAttr.minHeight, cstring"200px")):
              text outputStdout
        tdiv:
          h4: text "Stderr"
          tdiv(class = "s12 m6"):
            text &"{countWord($outputStderr)} chars, "
            text &"""{$($outputStderr).split("\n").len} lines"""
          tdiv(class = "input-field col s12"):
            textarea(id = "outputStderr", class = &"materialize-textarea {textInputColor}", style = style(StyleAttr.minHeight, cstring"200px")):
              text outputStderr
        tdiv:
          h4: text "Images"
          for img in outputImages:
            tdiv:
              # imgでbase64を表示するときに必要なメタ情報を追加
              img(src = "data:image/png;base64," & img)
    footer(class = &"page-footer {baseColor}"):
      tdiv(class = "footer-copyright"):
        tdiv(class = "container"):
          text "© 2019, jiro4989 ("
          a(href = "https://twitter.com/jiro_saburomaru"): text "@jiro_saburomaru"
          text "), Apache License, "
          a(href = "https://github.com/jiro4989/websh"): text "Repository"
          text ", "
          a(href = "https://stats.uptimerobot.com/EZnRXc325K"): text "Public Status Page"

when not defined modeTest:
  setRenderer createDom
