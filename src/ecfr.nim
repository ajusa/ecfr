import curly, jsony, std/[dirs, files, paths]

type EcfrClient = object
  url: string
  curl: Curly
  cache: bool

type 
  ListAgenciesResponse* = object
    agencies*: seq[Agency]
  Agency* = object
    name*: string
    cfrReferences*: seq[CfrReference]
    children*: seq[Office]
  CfrReference* = object
    title*: int
    chapter*: string
  Office* = object
    cfrReferences*: seq[CfrReference]
  ListTitlesResponse* = object
    titles*: seq[TitleSummary]
  TitleSummary* = object
    number*: int
    name*: string
  Section* = object
    identifier*: string
    labelLevel*: string
    labelDescription*: string
    size*: int
    reserved*: bool
    `type`*: string
    children*: seq[Section]

proc initEcfrClient*(url = "https://ecfr.gov", cache = false): EcfrClient =
  EcfrClient(url: url, curl: newCurly(), cache: cache)

proc get(conn: EcfrClient, path: string): string =
  let location = Path("cache" & path)
  if conn.cache:
    if fileExists(location): return readFile($location)
  result = conn.curl.get(conn.url & path).body
  if conn.cache:
    createDir(location.parentDir)
    writeFile($location, result)

proc listAgencies*(conn: EcfrClient): ListAgenciesResponse =
  conn.get("/api/admin/v1/agencies.json").fromJson(ListAgenciesResponse)

proc listTitles*(conn: EcfrClient ): ListTitlesResponse =
  conn.get("/api/versioner/v1/titles.json").fromJson(ListTitlesResponse)

proc getTitle*(conn: EcfrClient, title: string, date = "2025-01-01"): Section =
  conn.get("/api/versioner/v1/structure/" & date & "/title-" & title & ".json").fromJson(Section)

when isMainModule:
  import sugar
  let client = initEcfrClient()
  # dump client.listAgencies()
  dump client.getTitle("42")