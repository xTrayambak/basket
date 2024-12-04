import std/[os, options, logging]
import pkg/[jsony]

type
  ## A bunch of paths that have been crawled already and can be directly read without having to go through the entire filesystem-walk
  ## procedure again
  TraversalCache* = seq[string]

proc validate*(cache: TraversalCache): bool =
  for file in cache:
    if not fileExists(file):
      debug "traversal_cache: " & file & " no longer exists, traversal cache has been invalidated"
      return false

  true

proc save*(cache: TraversalCache) =
  debug "traversal_cache: saving " & $cache.len & " items to traversal cache"
  discard existsOrCreateDir(getCacheDir() / "basket")
  writeFile(getCacheDir() / "basket" / "traversal_cache.json", toJson cache)

proc getTraversalCache*: Option[TraversalCache] =
  let dir = getCacheDir() / "basket"
  if not existsOrCreateDir(dir):
    return

  if not fileExists(dir / "traversal_cache.json"):
    return

  let data = readFile(dir / "traversal_cache.json")
  debug "traversal_cache: read " & $data.len & " byte(s)."

  try:
    let cache = fromJson(data, TraversalCache)
    if cache.validate():
      return some(cache)
    else:
      debug "traversal_cache: cache validation has failed, cache has been invalidated. billions must die."
  except JsonError as exc:
    warn "traversal_cache: failed to read traversal cache"
    warn "traversal_cache: " & exc.msg
