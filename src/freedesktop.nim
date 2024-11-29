import std/[os, options, strutils, tables, logging, hashes]
import pkg/[iniplus]
import ./sugar

type
  DesktopEntry* = object
    name*, exec*: string
    icon*, actions*: Option[string]
    categories*: seq[string]
    terminal*: bool
    path*: string

func hash*(entry: DesktopEntry): Hash {.inline.} =
  var hash: Hash
  hash = hash !& hash(entry.name)
  hash = hash !& hash(entry.exec)

  if *entry.icon:
    hash = hash !& hash(entry.icon)

  if *entry.actions:
    hash = hash !& hash(entry.actions)

  hash = hash !& hash(entry.categories)
  hash = hash !& hash(entry.terminal)
  hash = hash !& hash(entry.path)

  hash

proc readDesktopEntry*(path: string): Option[DesktopEntry] =
  info "freedesktop: reading desktop entry: " & path

  if not fileExists(path):
    warn "freedesktop: cannot parse desktop entry as file doesn't exist: " & path
    return

  let rawContent = readFile(path)
  var content: string

  for line in rawContent.splitLines():
    if line.startsWith('#'): continue
    content &= line & '\n'
  
  if content.len < 1:
    warn "freedesktop: cannot parse desktop entry as file is empty: " & path
    return

  let parsed = iniplus.parseString(content)
  if not parsed.exists("Desktop Entry", "Name"):
    warn "freedesktop: cannot get name of application in desktop entry, ignoring: " & path
    return

  var entry: DesktopEntry
  entry.path = path
  try:
    entry.name = parsed.getString("Desktop Entry", "Name")
  except ValueError:
    warn "freedesktop: cannot interpret INI file as desktop entry - application name is not defined: " & path
    return

  if parsed.exists("Desktop Entry", "Terminal"):
    entry.terminal = parsed.getBool("Desktop Entry", "Terminal")

  try: # FIXME: use a better INI parser that can handle these desktop entries. Stuff like Description[language] completely throws off iniplus...
    for t, _ in parsed:
      let (toplevel, _) = t
      if parsed.exists(toplevel, "Exec"):
        entry.exec = parsed.getString(toplevel, "Exec")
  except ValueError:
    warn "freedesktop: cannot interpret INI file as desktop entry - application binary is not defined: " & path
    return

  if parsed.exists("Desktop Entry", "Actions"):
    debug "freedesktop: desktop entry contains actions data: " & path
    entry.actions = some(parsed.getString("Desktop Entry", "Actions"))

  if parsed.exists("Desktop Entry", "Icon"):
    debug "freedesktop: desktop entry contains icon data: " & path
    entry.icon = some(parsed.getString("Desktop Entry", "Icon"))

  if parsed.exists("Desktop Entry", "Categories"):
    debug "freedesktop: desktop entry contains category data: " & path 
    entry.categories = parsed.getString("Desktop Entry", "Categories").split(';')
  
  some(entry)
