import mummy, mummy/routers, webby, debby/sqlite, jsony
import std/[sequtils, xmltree, strformat]
import std/strutils except escape

type AgencyCount = ref object
  name: string
  count: int

type 
  Chart = object
    title: string
    data: ChartData
    `type`: string
  ChartData = object
    labels: seq[string]
    datasets: seq[Dataset]
  Dataset = object
    values: seq[int]

proc toChart(agencyCounts: seq[AgencyCount]): Chart =
  let counts = agencyCounts[0..min(9, agencyCounts.len - 1)]
  result.title = "Regulation (millions of words) by agencies"
  result.data.labels = counts.mapIt(it.name)
  result.data.datasets = @[Dataset(values: counts.mapIt(it.count div 1_000_000))]
  result.`type` = "bar"


proc respondHtml*(request: Request, value: string) =
  request.respond(200, @[("Content-Type", "text/html")], value)

proc generateOrderBy(order: string): string =
  if order == "wordsAsc": return "count ASC"
  if order == "nameAsc": return "name ASC"
  if order == "nameDesc": return "name DESC"
  return "count DESC"


let db = openDatabase("ecfr.db")

include "template.html"

var router: Router
router.get "/", proc (request: Request) = 
  let orderBy = request.queryParams["sort"].generateOrderBy()
  let agencies = db.query(
    AgencyCount,
    &"""
    SELECT name, SUM(chapter.size) AS count 
    FROM agency JOIN chapter ON agency.id = chapter.agency_id 
    WHERE name LIKE ?
    GROUP BY name ORDER BY {orderBy}
    """,
    '%' & request.queryParams["filter"] & '%')
  request.respondHtml(render(agenciesIndex(agencies)))

let server = newServer(router)
echo "Serving on http://localhost:2384"
server.serve(Port(2384))
