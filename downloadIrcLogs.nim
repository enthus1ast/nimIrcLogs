import nimiBrowser
import asyncdispatch, tables, strtabs, os,
  strutils, uri, httpcore, httpclient, times
export times
const baseUrl = parseUri "https://irclogs.nim-lang.org/"

type
  DateStr = string
  Raw = object
    url: string
    body: string


proc getDate*(body: string): DateTime =
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
  result = parse(dateStr, "dd-MM-yyyy")
  # result.timezone = utc()

proc toDateStr(dt: DateTime): string =
  return dt.format("dd-MM-yyyy")


when isMainModule:
  echo getDate("<html><head><title>#nim logs for 26-04-2022</title><meta c")


  var br = newNimiBrowser()
  var startDate = waitFor((waitFor br.get($baseUrl)).body).getDate()

  var curDate = startDate
  var errors = 0
  while true:
    if errors > 50:
      echo "done?"
      break
    curDate = curDate - initDuration(days = 1)
    let curDateStr = curDate.toDateStr()
    if existsFile(curDateStr & ".html"):
      echo "[-] ", curDateStr
      errors = 0
    else:
      echo "[+] ", curDateStr
      let resp = waitFor br.get $(baseUrl / (curDateStr & ".html"))
      if resp.code != Http200:
        echo "error"
        errors.inc
        continue
      errors = 0
      writeFile(curDateStr & ".html", waitFor resp.body)
