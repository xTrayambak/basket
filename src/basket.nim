import std/[logging]
import pkg/[colored_logger]
import ./[crawler, viewer]

proc main =
  logging.addHandler(newColoredLogger())
  logging.setLogFilter(lvlInfo)

  var entries = crawlForDesktopEntries()
  var viewer = runBasketViewer(move(entries))

when isMainModule:
  main()
