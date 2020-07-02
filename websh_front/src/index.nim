from strutils import split
from strformat import `&`
from unicode import isAlpha, toRunes, runeAt, `==`, `$`
from uri import encodeUrl
from sequtils import mapIt, toSeq, filterIt

import karax / [kbase, vdom, kdom, vstyles, karax, karaxdsl, jdict, jstrutils, jjson, kajax]

type
  ResponseResult = object
    status: cint
    system_message: cstring
    stdout: cstring
    stderr: cstring
    images: seq[ImageObj]
    elapsed_time: cstring
  ImageObj = object
    image: cstring
    filesize: cint
  MediaObj = object
    name, data: cstring

const
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

proc newMediaObj(): MediaObj = MediaObj(name: cstring"", data: cstring"")

var
  inputShell = cstring""
  inputImages = [newMediaObj(), newMediaObj(), newMediaObj(), newMediaObj()]
  outputStatus = cint(0)
  outputSystemMessage = cstring""
  outputStdout = cstring""
  outputStderr = cstring""
  outputImages: seq[ImageObj]
  outputElapsedTime = cstring"0milsec"
  isProgress: bool
    ## シェルの実行中表示を切り替えるためのフラグ
  hashTag = cstring"シェル芸"

proc respCb(httpStatus: int, response: cstring) =
  let resp = fromJson[ResponseResult](response)
  outputStatus = resp.status
  outputSystemMessage = resp.system_message
  outputStdout = resp.stdout
  outputStderr = resp.stderr
  outputImages = resp.images
  outputElapsedTime = resp.elapsed_time
  # シェルの実行中表示 OFF
  isProgress = false

proc sendShellButtonOnClick(ev: Event, n: VNode) = # シェルの実行中表示 ON
  isProgress = true
  let images = inputImages.filterIt(it.name != cstring"").mapIt(it.data)
  let body = %*{"code": inputShell, "images": images}
  ajaxPost(apiUrl,
    headers = @[
      (cstring"mode", cstring"cors"),
      (cstring"cache", cstring"no-cache"),
      ],
    data = body.toJson,
    cont = respCb)

proc inputTextareaOnkeydown(ev: Event, n: VNode) =
  let kbEvt = cast[KeyboardEvent](ev)
  # Ctrl + Enterで実行
  if kbEvt.ctrlKey and kbEvt.keyCode == 13:
    sendShellButtonOnClick(ev, n)

proc inputTextareaOnkeyup(ev: Event, n: VNode) =
  inputShell = $n.value

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

proc encode*(data: kdom.File, f: proc(data: cstring)) {.importc.}

proc uploadFileButtonOnClicked(i: int): proc(ev: Event, n: VNode) =
  let i = i
  result = proc (ev: Event, n: VNode) =
    let elem = cast[InputElement](ev.target)
    if elem.files.len < 1: return
    let file = cast[kdom.File](elem.files[0])
    inputImages[i].name = file.name
    let f = proc(data: cstring) =
      inputImages[i].data = data
    encode(file, f)

proc deleteFileButtonOnClicked(i: int): proc(ev: Event, n: VNode) =
  let i = i
  result = proc (ev: Event, n: VNode) =
    inputImages[i].name = cstring""
    inputImages[i].data = cstring""

proc createDom(): VNode =
  result = buildHtml(tdiv):

    # ヘッダー
    section(class = "hero is-dark"):
      tdiv(class = "hero-body"):
        tdiv(class = "container"):
          tdiv(class = "content has-text-centered"):
            h1(class = "title"): text "websh"

    # システムメッセージの表示
    nav(class = "level"):
      tdiv(class = "level-item has-text-centered"):
        tdiv:
          p(class = "heading"): text "system message"
          p(class = "title"):
            if isProgress:
              text "Running ..."
            elif outputStatus != statusOk:
              text &"{outputSystemMessage} ({outputElapsedTime})"
            else:
              text &"none ({outputElapsedTime})"

    # 入力、出力スペース
    tdiv(class = "columns is-desktop"):
      tdiv(class = "column"):
        tdiv(class = "tile is-ancestor"):
          tdiv(class = "tile is-parent is-vertical"):
            article(class = "tile is-child notification"):
              p(class = "title"): text "input"
              p(class = "subtitle"):
                tdiv:
                  let count = countWord($inputShell)
                  tdiv:
                    text &"{$count} chars"
                  let remain = 280 - count
                  let remainPercent = int(count / 280 * 100)
                  let color =
                    if 100 <= remainPercent: "has-background-danger"
                    elif 70 <= remainPercent: "has-background-warning"
                    else: ""
                  tdiv(class = color):
                    text &"Remaining: {$remain} chars ({$remainPercent}%)."
              tdiv(class = "content"):
                tdiv:
                  textarea(class = "textarea is-primary",
                           placeholder = "ex: echo 'Hello shell'",
                           rows = "15",
                           setFocus = true,
                           onkeydown = inputTextareaOnkeydown,
                           onkeyup = inputTextareaOnkeyup,
                           )
                for ii in 0..<inputImages.len:
                  tdiv(class="file has-name is-primary"):
                    label(class="file-label"):
                      input(class="file-input", accept="image/*", `type`="file", name="images", onchange=uploadFileButtonOnClicked(ii))
                      span(class="file-cta"):
                        span(class="file-label"):
                          text "image file"
                      span(class="file-name"):
                        if inputImages[ii].name == cstring"":
                          text "no file"
                        else:
                          text inputImages[ii].name
                    if inputImages[ii].name != cstring"":
                      button(class="button has-background-danger", onclick=deleteFileButtonOnClicked(ii)):
                        text "Delete"
                tdiv(class = "buttons"):
                  button(class="button is-primary", onclick = sendShellButtonOnClick):
                    text "Run (Ctrl + Enter)"
                  a(href = &"""https://twitter.com/intent/tweet?hashtags={encodeUrl($hashTag, false)}&text={encodeUrl($inputShell, false)}&ref_src=twsrc%5Etfw""",
                      class = "button twitter-share-button is-link",
                      `data-show-count` = "false"):
                    text "Tweet"
                  tdiv(class = "select"):
                    select:
                      proc onchange(ev: Event, n: VNode) =
                        hashTag = $n.value
                      for elem in @[cstring"シェル芸", cstring"shellgei", cstring"ゆるシェル", cstring"危険シェル芸", ]:
                        option(value = $elem):
                          text $elem
      tdiv(class = "column"):
        tdiv(class = "tile is-ancestor"):
          tdiv(class = "tile is-parent is-vertical"):
            article(class = "tile is-child notification"):
              p(class = "title"): text "stdout"
              p(class = "subtitle"):
                tdiv:
                  text &"{countWord($outputStdout)} chars, "
                  text &"""{$($outputStdout).split("\n").len} lines"""
                tdiv:
                  textarea(class = "textarea is-success", rows = "8", readonly="readonly"):
                    text outputStdout
            article(class = "tile is-child notification"):
              p(class = "title"): text "stderr"
              p(class = "subtitle"):
                tdiv:
                  text &"{countWord($outputStderr)} chars, "
                  text &"""{$($outputStderr).split("\n").len} lines"""
                tdiv:
                  textarea(class = "textarea is-warning", rows = "4", readonly="readonly"):
                    text outputStderr
            article(class = "tile is-child notification"):
              p(class = "title"): text "images"
              tdiv(class = "content"):
                for img in outputImages:
                  tdiv:
                    # imgでbase64を表示するときに必要なメタ情報を追加
                    img(src = "data:image/png;base64," & img.image)
                  tdiv:
                    text &"{img.filesize} byte"

    footer(class = &"footer"):
      tdiv(class = "container"):
        tdiv(class = "content has-text-centered"):
          text "© 2019, jiro4989 ("
          a(href = "https://twitter.com/jiro_saburomaru"): text "@jiro_saburomaru"
          text "), Apache License, "
          a(href = "https://github.com/jiro4989/websh"): text "Repository"
          text ", "
          a(href = "https://stats.uptimerobot.com/EZnRXc325K"): text "Public Status Page"

when not defined modeTest:
  setRenderer createDom
