import std/[os, strutils, logging]
import pkg/[colored_logger]
import ./[crawler, viewer, config, argparser]

const NimblePkgVersion {.strdefine.} = "<\e[31mnot defined\e[0m>"

proc versionCmd {.noReturn, inline.} =
  echo "basket v" & NimblePkgVersion
  var features: string

  template yes(feature: string) =
    features &= "\e[32m+" & feature.toUpperAscii() & "\e[0m "

  template no(feature: string) =
    features &= "\e[31m-" & feature.toUpperAscii() & "\e[0m "

  when defined(release):
    yes "release"
    no "debug"
  else:
    no "release"
    yes "debug"

  when not defined(basketDisableConfig):
    yes "config"
  else:
    no "config"
  
  echo features
  quit(0)

proc main =
  logging.addHandler(newColoredLogger())
  logging.setLogFilter(lvlNone)

  var input = parseInput()
  if input.enabled("version", "v"):
    versionCmd()

  if input.enabled("verbose", "V"):
    logging.setLogFilter(lvlAll)
  
  when not defined(basketDisableConfig):
    let configDir = getConfigDir() / "basket"
    discard existsOrCreateDir(configDir)
  
    if fileExists(configDir / "config.js"):
      loadConfig(configDir / "config.js", input)

  var entries = crawlForDesktopEntries()

  var viewer = runBasketViewer(move(input), move(entries))

when isMainModule:
  main()
