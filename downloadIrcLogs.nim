import nimiBrowser
import asyncdispatch, tables, strtabs, os,
  strutils, uri, httpcore, httpclient
import chrono
export chrono

const baseUrl = parseUri "https://irclogs.nim-lang.org/"
let basePath* = getAppDir() / "pages"

type
  DateStr = string
  Raw = object
    url: string
    body: string

proc getDate*(body: string): TimeStamp =
  const ss = "<title>"
  const ee = "</title>"
  var ssi = body.find(ss)
  if ssi == -1: raise newException(ValueError, "dateNotFound")
  ssi.inc ss.len
  var eei =  body.find(ee, ssi)
  if eei == -1: raise newException(ValueError, "dateNotFound")
  eei.dec # skip <
  let title = body[ssi .. eei]
  var dateStr = title.split(" ")[^1]
  var dateParts = dateStr.split("-")
  if dateParts[1].len == 3:
    dateParts[1] = dateParts[1][1..^1] #strip first
  dateStr = dateParts.join("-")
  result =  parseTs("{day/2}-{month/2}-{year/4}", dateStr)

proc toDateStr(dt: TimeStamp): string =
  # return dt.format("dd-MM-yyyy")
  return dt.format("{day/2}-{month/2}-{year/4}")

when isMainModule:
  # echo getDate("<html><head><title>#nim logs for 26-04-2022</title><meta c")

  var br = newNimiBrowser()
  var startDate = waitFor((waitFor br.get($baseUrl)).body).getDate()

  var curDate = startDate
  var errors = 0
  while true:
    if errors > 50:
      echo "done?"
      break
    var cal = curDate.calendar()
    echo cal
    cal.sub(Day, 1)
    curDate = cal.ts()
    let curDateStr = curDate.toDateStr()
    if existsFile(basePath / curDateStr & ".html"):
      echo "[-] ", curDateStr
      errors = 0
    else:
      let url = $(baseUrl / (curDateStr & ".html"))
      echo "[+] ", url
      let resp = waitFor br.get url
      if resp.code != Http200:
        echo "error"
        # echo waitFor resp.body
        errors.inc
        continue
      errors = 0
      writeFile(basePath / curDateStr & ".html", waitFor resp.body)
