import sugar
import sets
import strutils
import plotly
import chrono
import db_sqlite
import parse
import sequtils, tables
import times
import strformat

var db = open("entries.sqlite", "", "", "")

#############################
## Show all users per month
#############################
when false:
  let usersPerYear = db.getAllUsersPerYear()

  # var colors = @[Color(r:0.9, g:0.4, b:0.0, a: 1.0),
  #                Color(r:0.9, g:0.4, b:0.2, a: 1.0),
  #                Color(r:0.2, g:0.9, b:0.2, a: 1.0),
  #                Color(r:0.1, g:0.7, b:0.1, a: 1.0),
  #                Color(r:0.0, g:0.5, b:0.1, a: 1.0)]
  var usersActivePerMonth = Trace[int](mode: PlotMode.LinesMarkers, `type`: PlotType.Scatter, name: "User Active")
  var size = @[16.int]
  # d.xs = collect:
  #   for key in usersPerYear.keys(): parseInt(key.split("-")[0])

  usersActivePerMonth.ys = collect:
    for val in usersPerYear.values(): val.len

  usersActivePerMonth.text = collect:
    for key in usersPerYear.keys(): key

  var layout = Layout(title: fmt"Nim Users active in IRC per Month<br>generated:{now()}", width: 1200, height: 400,
                      xaxis: Axis(title:"Year"),
                      yaxis:Axis(title: "Users"), autosize:false)
  var p = Plot[int](layout:layout, traces: @[usersActivePerMonth])
  p.show()


#############################
## Show user from to
#############################
import std/algorithm
when true:

  var uft = collect:
    for user in db.getUsers():
      db.getFirstAndLastPost(user)
  echo uft

  proc myCmp(x, y: auto): int =
    let xx = x.newTime.int - x.oldTime.int
    let yy = y.newTime.int - y.oldTime.int
    cmp(xx, yy)

  uft.sort(myCmp, order = Descending)
  # uft = uft[0..100]

  var traces: seq[Trace[int]] = @[]
  for idx, uu in uft:
    var usersFromTo = Trace[int](mode: PlotMode.LinesMarkers, `type`: PlotType.Scatter, name: uu.realNick)
    # var size = @[16.int]
    usersFromTo.xs = @[uu.oldTime.int, uu.newTime.int]
    usersFromTo.ys = @[idx, idx]
    usersFromTo.text = @[uu.oldTime.formatIso & " " & uu.realNick, uu.newTime.formatIso & " " & uu.realNick]
    traces.add usersFromTo
    # userFromTo.ys = collect:
    #   for val in usersPerYear.values(): val.len

    # usersActivePerMonth.text = collect:
    #   for key in usersPerYear.keys(): key

  var layout = Layout(title: fmt"100 Longest active Nimusers", width: 1200, height: 2500,
                      xaxis: Axis(title:"Year"),
                      yaxis:Axis(title: "Users"), autosize:false)
  var p = Plot[int](layout:layout, traces: traces)
  p.show()
