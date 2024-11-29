## Basket crawler - crawls certain locations for desktop entries
import std/[os, distros, strutils, logging]
import ./[sugar, freedesktop]

proc home: string {.inline.} = getHomeDir()

proc getTargetDirectories*: seq[string] =
  ## Returns a vector of directories that are guaranteed to exist on the system
  var targets: seq[string]
  let home = home()

  if detectOs(NixOS):
    info "NixOS detected, adding ~/.nix-profile/share/applications"
    let dir = home / ".nix-profile" / "share" / "applications"
    if not dirExists(dir):
      warn "That directory doesn't exist even though we're supposedly in a Nix environment, weird."
    else:
      targets &= dir

  let localShare = home / ".local" / "share" / "applications"
  if dirExists(localShare):
    targets &= localShare

  let usrShareApps = '/' & "usr" / "share" / "applications"
  if dirExists(usrShareApps):
    targets &= usrShareApps

  targets

proc crawlForDesktopEntries*: seq[DesktopEntry] =
  let targets = getTargetDirectories()

  info "crawler: beginning crawl on " & $targets.len & " targets"

  var entries: seq[DesktopEntry]
  var candidates: seq[string]
  for target in targets:
    info "crawler: crawling target: " & target

    for kind, file in walkDir(target):
      if kind notin { pcFile, pcLinkToFile }: continue
      let path =
        if kind != pcFile:
          expandSymlink(file)
        else:
          file
      
      if not path.endsWith(".desktop"):
        continue

      candidates &= path
  
  for candidate in candidates:
    let entry = readDesktopEntry(candidate)
    if *entry:
      entries &= &entry

  entries
