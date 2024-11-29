import std/[algorithm]
import pkg/[fuzzy]

proc search*(part: string, choices: seq[string]): seq[string] =
  var res: seq[tuple[value: string, cost: float]]
  for choice in choices:
    let distance = fuzzyMatchSmart(part, choice)
    res &= (value: choice, cost: distance)

  res.sort(
    proc(x, y: tuple[value: string, cost: float]): int {.closure.} =
      cmp(y.cost, x.cost)
  )
  
  var final: seq[string]
  for score in res:
    final &= score.value

  final
