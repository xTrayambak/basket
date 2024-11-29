import std/[algorithm, os, logging, tables, hashes]
import pkg/[jsony, pretty]
import ./freedesktop

when defined(amd64) or defined(arm64):
  type UsageMetric* = uint64 ## 64-bit systems
else:
  type UsageMetric* = uint32 ## 32-bit systems

type
  UsageInfo* = Table[string, UsageMetric]

func `[]`*(usage: UsageInfo, entry: DesktopEntry): UsageMetric {.inline.} =
  let hashed = $entry.hash()
  if usage.contains(hashed):
    return usage[hashed]

  default(UsageMetric)

func `[]=`*(usage: var UsageInfo, entry: DesktopEntry, value: UsageMetric) {.inline.} =
  let hashed = entry.hash()
  usage[$hashed] = value

proc getBaseUsageDir*: string =
  let dir = getCacheDir() / "basket"
  if not dirExists(dir): createDir(dir)

  dir

proc getUsageInfo*: UsageInfo =
  let dir = getBaseUsageDir()
  let file = dir / "usage.json"

  if not file.fileExists():
    debug "usage_history: usage metrics don't exist, creating placeholder."
    writeFile(file, "{}")
    return default(UsageInfo)
  
  try:
    fromJson(readFile(file), UsageInfo)
  except JsonError as exc:
    error "usage_history: cannot read usage metrics: " & exc.msg
    error "usage_history: creating placeholder and resetting erroneous data."
    writeFile(file, "{}")
    return default(UsageInfo)
  
proc save*(usage: UsageInfo) =
  let file = getBaseUsageDir() / "usage.json"
  info "usage_history: saving usage data to " & file
  writeFile(file, toJson(usage))

var db = getUsageInfo() # We can get away with this since we're not really aiming for GC-safety (we're single threaded, yay!)
                        # Plus, this is only changed once per execution, so we don't need to worry about reloading this.

proc bumpUsageForEntry*(entry: DesktopEntry) =
  db[entry] = db[entry] + 1
  db.save()

proc sortAccordingToUsage*(entries: seq[DesktopEntry]): seq[DesktopEntry] =
  var mEntries = newSeq[DesktopEntry](entries.len)
  var res: seq[tuple[value: DesktopEntry, used: UsageMetric]]

  for entry in entries:
    res &= (value: entry, used: db[entry])

  res.sort(
    proc(x, y: tuple[value: DesktopEntry, used: UsageMetric]): int {.closure.} =
      cmp(y.used, x.used)
  )

  for i, rank in res:
    mEntries[i] = rank.value

  move(mEntries)
