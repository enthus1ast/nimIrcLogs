import std/htmlparser
import std/xmltree  # To use '$' for XmlNode
import std/strtabs  # To access XmlAttributes
import std/os       # To use splitFile
import std/strutils # To use cmpIgnoreCase
import downloadIrcLogs
import parseutils
import db_sqlite
import nisane
import sets, print

var knownBridges = @["FromDiscord", "FromDiscord_", "nrds", "FromGitter", "FromSlack", "FromMatrix3"]

import tables
import marshal

type
  MsgType = enum
    Join = "join",
    MQuit = "quit",
    MMsg = "msg"
    MNick = "nick"
    MAction = "action" # self talk
    MPart = "part" # legacy quit?
  Msg = object
    kind: MsgType
    time: TimeStamp
    nick: string
    realNick: string # if bridged, this should contain the real nick
    msg: string
    realMsg: string
    file: string
  Interaction = object
    userA: string
    userB: string
    count: int

const allowedNickChars = Letters + Digits
var commonEnglishWords = readFile("commonEnglishWords.txt").splitLines().toHashSet()


proc getYears(db: DbConn): seq[string] =
  ## Returns all years with logs available
  for row in db.getAllRows(sql"select strftime('%Y-%m', time) as year from Msg group by year order by year asc;"):
    result.add row[0]

# proc getUsers(db: DbConn): seq[string] =
#   ## Returns all users

proc toTimestamp(str: string): TimeStamp =
  parseIsoTs(str)

proc getFirstAndLastPost*(db: DbConn, realNick: string): tuple[realNick: string, oldId: int, oldTime: Timestamp, newId: int, newTime: Timestamp] =
  let rows = db.getAllRows(sql"""
    select * from (
      (select realNick, id as oldId, time as oldTime from Msg where realNick = ? order by time asc limit 1) ,
      (select id as newId, time as newTime from Msg where realNick = ? order by time desc limit 1)
    )
  """, realNick, realNick)
  rows[0].to(result)


proc getUsers*(db: DbConn): HashSet[string] =
  let rows = db.getAllRows(sql"select realNick from Msg where realNick != '' group by realNick;")
  for row in rows:
    result.incl row[0]

proc getUsers*(db: DbConn, year: string): HashSet[string] =
  ## get users for the given year
  for row in db.getAllRows(sql"select realNick from Msg where  strftime('%Y-%m', time) = ? and realNick != '' GROUP by realNick", year):
    result.incl row[0]


proc getAllUsersPerYear*(db: DbConn): OrderedTable[string, HashSet[string]] =
  result = initOrderedTable[string, HashSet[string]]()
  for year in db.getYears():
    result[year] = db.getUsers(year)
    print year, result[year].len()

proc getMsgs*(db: DbConn, yearMonth: string): seq[string] =
  ## get msgs per yearMonth
  for row in db.getAllRows(sql"select msg from Msg where strftime('%Y-%m', time) = ? and realNick != ''", yearMonth):
    result.add row[0]

proc getAllMsgsPerYear*(db: DbConn): OrderedTable[string, seq[string]] =
  for year in db.getYears():
    result[year] = db.getMsgs(year)
#
# Lost forever, computes users that
# where in the sets before, but not in the newer sets
# let yy = toSeq(result.keys())


proc normalizeNick(nick: string): string =
  for ch in nick:
    if ch in allowedNickChars:
      result.add ch.toLowerAscii()

proc extractRealNick(msg: var Msg) =
  template nickToRealnick() =
    msg.realNick = msg.nick
    msg.realMsg = msg.msg

  if msg.nick in knownBridges:
    if msg.msg.isEmptyOrWhitespace:
      nickToRealnick()
    elif msg.msg[0] == '<':
      var prefixLen = parseUntil(msg.msg, msg.realNick, '>', 1)
      prefixLen.inc # skip >
      prefixLen.inc # skip " " after >
      msg.realMsg = msg.msg[prefixLen + 1 .. ^1]
    else:
      nickToRealnick()
  else:
    nickToRealnick()
  msg.realNick = msg.realNick.normalizeNick()
  msg.nick = msg.nick.normalizeNick()

iterator parseMsgs(path: string): Msg =
  let html = loadHtml(path)
  var date = ($html).getDate()
  for tr in html.findAll("tr"):
    var msg = Msg()
    msg.file = path
    if not tr.attrs.isNil:
      if tr.attrs.hasKey "class":
        let class = tr.attrs.getOrDefault "class"
        try:
          msg.kind = parseEnum[MsgType](class)
        except:
          echo getCurrentExceptionMsg()
          echo tr
          quit()
    else:
      msg.kind = MMsg
      var tds = tr.findAll("td")
      if tds.len >= 3:
        try:
          # let time = tds[0].innerText.parse("hh':'mm':'ss")
          # let time = tds[0].innerText.parseTs("{hour/2}:{minute/2}:{second/2}")
          # date.hour = time.hour
          # date.minute = time.minute
          # date.second = time.second
          # msg.time = date
          var cal = date.calendar()
          let timePart = parseCalendar("{hour/2}:{minute/2}:{second/2}", tds[0].innerText)
          cal.add(Hour, timePart.hour)
          cal.add(Minute, timePart.minute)
          cal.add(Second, timePart.second)
          msg.time = cal.ts()
        except:
          echo getCurrentExceptionMsg()
          echo "Date will be incorrect!"
        msg.nick = tds[1].innerText
        msg.msg = tds[2].innerText
        extractRealNick(msg)
        yield msg


when isMainModule and false:
  var users = initCountTable[string]()
  var idx = 0
  var outp = open("msgs.nn", fmWrite)
  var msgs: seq[Msg] = @[]
  for path in walkFiles(basePath / "*.html"):
    # block:
    # let path = """C:\Users\david\projects\nimIrclogs\27-03-2022.html"""
    for msg in parseMsgs(path):
      # echo idx, " ", msg
      # idx.inc
      msgs.add msg
      # echo msg
      # users.inc(msg.realNick)
  outp.write $$msgs
  # echo users

# proc getUsers(msgs: seq[Msg]): HashSet[string] =
#   result = initHashSet[string]()
#   for msg in msgs:
#     result.incl msg.realNick

proc getUserInteractions(db: DbConn) = #users: HashSet[string], msgs: seq[Msg]): Table[string, HashSet[string]] =
  db.exec(sql("drop table if exists Interaction;"))
  db.exec(sql ct(Interaction))
  let users = db.getUsers()
  for user in users:
    # let query = "select realNick, count(realNick) from Msg where lower(realMsg) like '%" & user & "%' group by realNick;"

    let query = """select Msg.realNick, count(Msg.realNick) from MsgFts, Msg where MsgFts.realMsg match '"""" & user.replace("?", "").replace("'","") & """"' and MsgFts.rowId = Msg.id  group by RealNick;"""
    # """ # fix nvim parser.....
    print user #, rows
    let rows = db.getAllRows(sql(query))
    db.exec(sql "begin transaction;")
    for row in rows:
      var interaction = Interaction()
      interaction.userA = user
      interaction.userB = row[0]
      interaction.count = row[1].parseInt()
      db.exec(sql ci(Interaction), interaction.userA, interaction.userB, $interaction.count)
    db.exec(sql "commit;")

  # result = initTable[string, HashSet[string]]()
  # for user in users:
  #   result[user] = initHashSet[string]()
  #   for msg in msgs:
  #     if user in msg.realMsg:
  #       print user, "->", msg.realNick
  #       result[user].incl msg.realNick

when isMainModule and false:
  # let data = readFile("msgs.nn")
  # print "read done"
  # var msgs = to[seq[Msg]](data)
  # print "load done"
  # let users = msgs.getUsers()
  # let userInteraction = getUserInteractions(users, msgs)
  # writeFile("userInteraction.nn", $$ userInteraction)
  var db = open("entries.sqlite", "", "", "")
  db.getUserInteractions()


when isMainModule and true:
  var db = open("entries.sqlite", "", "", "")
  echo db.getAllUsersPerYear()
  for user in db.getAllRows(sql"select distinct realNick from Msg"):
    echo db.getFirstAndLastPost(user[0])

when isMainModule and false:

  var db = open("entries.sqlite", "", "", "")
  db.exec(sql"drop table if exists Msg;")
  db.exec(sql ct(Msg))

  db.exec(sql"begin transaction;")
  for path in walkFiles(basePath / "*.html"):
    for msg in parseMsgs(path):
      # print msg.nick, msg.realNick
      db.exec(sql ci(Msg), msg.kind, msg.time.formatIso(), msg.nick, msg.realNick, msg.msg, msg.realMsg, msg.file)
  db.exec(sql"commit;")

  db.exec(sql"""CREATE INDEX if not exists "msg_year" ON "Msg" ( strftime('%Y', time))""")
  db.exec(sql"""CREATE INDEX if not exists "msg_year_month" ON "Msg" ( strftime('%Y-%m', time))""")
  db.exec(sql"""CREATE INDEX if not exists "msg_year_month_day" ON "Msg" ( strftime('%Y-%m-%d', time))""")

  db.exec(sql"""
  create view if not exists log_year_month_day AS
    select strftime('%Y-%m-%d', time) as year_month_day from Msg group by year_month_day order by year_month_day asc;
  """)

  db.exec(sql"""
  create view if not exists log_year_month AS
    select strftime('%Y-%m', time) as year_month from Msg group by year_month order by year_month asc;
  """)

  db.exec(sql"""
  create view if not exists log_year AS
    select strftime('%Y', time) as year from Msg group by year order by year asc;
  """)

    # Create some indexes
    # db.exec(sql"""
    #   CREATE INDEX "msg_nick" ON "Msg" (
    #   "realNick"
    #   );
    # """)

    # db.exec(sql"""
# CREATE INDEX "msg_time" ON "Msg" (
# "time"
# )
    # """)

    # db.exec(sql"""
  # CREATE INDEX "msg_year" ON "Msg" (
# "time"
# ) WHERE strftime('%Y', time)
    # """)


  db.close()

when isMainModule and false:
  let path = "25-05-2020.html"
  parseMsgs(path)



# -- Most messages overall
# select realNick, count(realNick) as msgs from Msg group by realNick  order by msgs desc limit 100;

# --
# select count(id) msgPerYear, strftime('%Y', time) year from Msg group by year order by year;
# select count(id) msgPerYear, time, strftime('%Y', time) year,  strftime('%m', time) month, strftime('%d', time) day from Msg group by year order by msgPerYear
# --drop table Msg;
# select count(id) msgPerYear, time, strftime('%Y-%m', time) yearMonth from Msg group by yearMonth order by msgPerYear
#
#
# create VIRTUAL TABLE MsgFts USING fts5 (realMsg, content=Msg);

# insert into MsgFts (realMsg)
# select realMsg from Msg;

# select MsgFts.rowId, MsgFts.realMsg, Msg.realNick from MsgFts, Msg where MsgFts.realMsg match 'enthus1ast' and MsgFts.rowId = Msg.id  ;

# select Msg.realNick, count(Msg.realNick) from MsgFts, Msg where MsgFts.realMsg match 'enthus1ast' and MsgFts.rowId = Msg.id  group by RealNick;
# select Msg.realNick, count(Msg.realNick) from MsgFts, Msg where MsgFts.realMsg match 'enthus1ast' and MsgFts.rowId = Msg.id  group by RealNick;
