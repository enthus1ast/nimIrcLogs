import sugar
import nimja
import jester
import parse, tables, db_sqlite, sets
import jsdata
import chrono

var db = open("entries.sqlite", "", "", "")
var usersPerYear = db.getAllUsersPerYear()
let usersActivePerMonthCnt = collect:
  for val in usersPerYear.values(): val.len

var msgsPerYear = db.getAllMsgsPerYear()
let msgsPerMonthCnt = collect:
  for val in msgsPerYear.values(): val.len / 100

var idx = 0
var usersActivePerMonthCntTEST: seq[int]
for val in usersPerYear.values():
  if idx mod 3 == 0:
    usersActivePerMonthCntTEST.add val.len
  else:
    let c = val.len * 2
    usersActivePerMonthCntTEST.add c
  idx.inc

var usersActivePerMonthText = collect:
    for key in usersPerYear.keys(): parseTs("{year/4}-{month/2}" ,key).int

# var usersActivePerMonthText = collect:
#     for key in usersPerYear.keys(): parseTs("{year/4}-{month/2}" ,key).int


routes:
  get "/":
    resp tmpls("""

{%extends master.nimja%}
{%block content%}
FOO
{#
{% for (year, users) in db.getAllUsersPerYear().pairs %}
  <h2>{{year}}</h2>
  {{users.len}}
{% endfor %}
#}
<div class="plot1">
  plot1
</div>


		<script>
			let yrs = [2017,2018,2019];
			let mos = 'Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec'.split(",");

			let ts = [];

			yrs.forEach(y => {
				mos.forEach(m => {
				//	ts.push(Date.parse('11 ' + m + ' ' + y + ' 17:30:00 UTC')/1000);
				//	ts.push(Date.parse('01 ' + m + ' ' + y + ' 23:30:00 UTC')/1000);
					ts.push(Date.parse('01 ' + m + ' ' + y + ' 00:00:00 UTC')/1000);
				})
			});

			let vals = [0,1,2,3,4,5,6,7,8,9,10];

			//let data = [
			//	ts,
			//	ts.map((t, i) => i == 0 ? 5 : vals[Math.floor(Math.random() * vals.length)]),
			//];

      let data = [
        //{{ (0..usersActivePerMonthCnt.len-1).jarr() }},
        {{ usersActivePerMonthText.jarr() }},
        {{ usersActivePerMonthCnt.jarr() }},
        {{ msgsPerMonthCnt.jarr() }}
      ]

			const opts = {
				width: 1920,
				height: 600,
				title: "Active Nim IRC per month",
				tzDate: ts => uPlot.tzDate(new Date(ts * 1e3), 'Etc/UTC'),
				series: [
					{},
					{
            label: "User per month",
						stroke: "red",
					},
					{
            label: "100 msg per month",
						stroke: "blue",
					},
				],
				axes: [
					{
						space: (self, axisIdx, scaleMin, scaleMax, plotDim) => {
							let rangeSecs = scaleMax - scaleMin;
							let rangeDays = rangeSecs / 86400;
							let pxPerDay = plotDim / rangeDays;
							// ensure min split space is 28 days worth of pixels
							return pxPerDay * 28;
						},
					},
				],
			};

			let u = new uPlot(opts, data, document.body);
		</script>



{% endblock %}


""")
