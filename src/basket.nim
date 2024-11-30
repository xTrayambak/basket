import std/[os, logging]
import pkg/[colored_logger]
import ./[crawler, viewer, config]

proc main =
  logging.addHandler(newColoredLogger())
  logging.setLogFilter(lvlInfo)
  
  let configDir = getConfigDir() / "basket"
  discard existsOrCreateDir(configDir)
  
  if fileExists(configDir / "config.js"):
    loadConfig(configDir / "config.js")

  var entries = crawlForDesktopEntries()
  var viewer = runBasketViewer(move(entries))

when isMainModule:
  main()
