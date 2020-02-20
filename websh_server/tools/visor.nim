import os, osproc, strutils, sequtils

while true:
  for i in 1..4:
    let s = execProcess("docker-compose", args = ["ps"], options = {poUsePath})
    for name in s.split("\n").filterIt("Exit" in it).mapIt(it.split(" ")[0]):
      discard execShellCmd("docker-compose up -d " & name)
  sleep 500
