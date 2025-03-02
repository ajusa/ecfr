import debby/[sqlite], malebolgia, malebolgia/paralgos
import std/[tables, sequtils, strutils]
import ecfr

type 
  Agency* = ref object
    id*: int
    name*: string
  Chapter* = ref object
    id*: int
    size*: int
    identifier*: string
    labelLevel*: string
    labelDescription*: string
    agencyId*: int

# Creates a lookup table to get the agency id from a title and chapter
proc initAgencyLookup(agencies: seq[ecfr.Agency], 
                      dbAgencies: seq[Agency]): Table[tuple[title: int, chapter: string], int] =
  # In theory the agency index -> dbAgency id, but we'll match by agency name instead
  let agencyToId = dbAgencies.mapIt((it.name, it.id)).toTable
  for agency in agencies:
    for cfrRef in agency.cfrReferences:
      result[(cfrRef.title, cfrRef.chapter)] = agencyToId[agency.name]
    for child in agency.children:
      for cfrRef in child.cfrReferences:
        result[(cfrRef.title, cfrRef.chapter)] = agencyToId[agency.name]

proc getChapters(section: Section): seq[Section] =
  for child in section.children:
    if child.type == "chapter": result.add(child)
    for chapter in getChapters(child): result.add(chapter)

when isMainModule:
  echo "This program will generate a database with information from the eCFR"

  let db = openDatabase("ecfr.db")
  db.createTable(Agency)
  db.createTable(Chapter)

  let client = initEcfrClient(cache = true)
  echo "Fetching agencies..."
  let agencies = client.listAgencies().agencies
  let dbAgencies = agencies.mapIt(Agency(name: it.name))
  db.insert(dbAgencies)
  let unknownAgency = Agency(name: "Unknown")
  db.insert(unknownAgency)

  let lookup = initAgencyLookup(agencies, dbAgencies)

  echo "Fetching list of titles..."
  let titleSummaries = client.listTitles().titles

  echo "Fetching title information in parallel..."
  let ids = titleSummaries.mapIt($it.number)
  # Limit to 8 concurrent requests
  # let titles = ids.mapIt(client.getTitle(it))
  let titles = ids.parMap((ids.len div 8) + 1, proc (id: string): Section =
    {.cast(gcSafe).}: initEcfrClient(cache = true).getTitle(id)
  )

  echo "Inserting chapters into database..."
  var chapters: seq[Chapter]
  for title in titles:
    for chapter in getChapters(title):
      if not chapter.reserved:
        let agencyId = lookup.getOrDefault((title.identifier.parseInt, chapter.identifier), unknownAgency.id)
        chapters.add Chapter(size: chapter.size, agencyId: agencyId, identifier: chapter.identifier,
          labelLevel: chapter.labelLevel, labelDescription: chapter.labelDescription)
  db.insert(chapters)

  echo "Done!"