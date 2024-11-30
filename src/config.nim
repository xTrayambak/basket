import std/[math, strutils, tables]
import pkg/[pretty, nanovg]
import pkg/bali/grammar/prelude
import pkg/bali/runtime/prelude
import pkg/bali/internal/sugar
import pkg/bali/stdlib/errors

type
  JSRGB* = object
    r*, g*, b*: uint8

  JSRGBA* = object
    r*, g*, b*, a*: uint8

  ColorFor* = enum
    Background
    ItemBackground
    SelectedItemBackground
    Text

  BoundsHitBehaviour* {.pure.} = enum
    ## What to do when you either hit the top of the apps list or the bottom?
    Overflow ## If at top, go to bottom. If at bottom, go to top.
    Stay ## Stay as-is.

let
  DefaultColorScheme* = toTable {
    Background: rgba(18, 18, 18, 102),
    ItemBackground: rgba(33, 33, 33, 128),
    Text: rgba(255, 255, 255, 255),
    SelectedItemBackground: rgba(33, 33, 33, 200)
  }

proc jsToNvg*(color: MAtom): Color {.inline.} =
  if color.objFields.contains("a"):
    return rgba(byte &color["r"].getFloat(), byte &color["g"].getFloat(), byte &color["b"].getFloat(), byte &color["a"].getFloat())
  else:
    return rgb(byte &color["r"].getFloat(), byte &color["g"].getFloat(), byte &color["b"].getFloat())

type
  Config* = object
    colors*: Table[ColorFor, Color]
    boundsHit*: BoundsHitBehaviour

var config: Config

proc getConfig*: Config {.inline.} = config

proc generateConfigProcs*(runtime: Runtime) =
  runtime.registerType(prototype = JSRGB, name = "RGB")
  runtime.defineConstructor(
    "RGB",
    proc =
      if runtime.argumentCount() < 3:
        runtime.vm.typeError("Constructor RGB() expects 3 values, got " & $runtime.argumentCount())

      var
        r = runtime.ToNumber(&runtime.argument(1))
        g = runtime.ToNumber(&runtime.argument(2))
        b = runtime.ToNumber(&runtime.argument(3))
      
      if r mod 1 != 0:
        r = round(r * 255)

      if g mod 1 != 0:
        g = round(g * 255)

      if b mod 1 != 0:
        b = round(b * 255)

      var color = runtime.createObjFromType(JSRGB) # allocate the actual object
      color["r"] = wrap r
      color["g"] = wrap g
      color["b"] = wrap b

      ret color
  )

  runtime.registerType(prototype = JSRGBA, name = "RGBA")
  runtime.defineConstructor(
    "RGBA",
    proc =
      if runtime.argumentCount() < 4:
        runtime.vm.typeError("Constructor RGBA() expects 3 values, got " & $runtime.argumentCount())

      var
        r = runtime.ToNumber(&runtime.argument(1))
        g = runtime.ToNumber(&runtime.argument(2))
        b = runtime.ToNumber(&runtime.argument(3))
        a = runtime.ToNumber(&runtime.argument(4))
      
      if r mod 1 != 0:
        r = round(r * 255)

      if g mod 1 != 0:
        g = round(g * 255)

      if b mod 1 != 0:
        b = round(b * 255)

      if a mod 1 != 0:
        a = round(a * 255)

      var color = runtime.createObjFromType(JSRGBA) # allocate the actual object
      color["r"] = wrap r
      color["g"] = wrap g
      color["b"] = wrap b
      color["a"] = wrap a

      ret color
  )

  runtime.defineFn(
    "setBackgroundColor",
    proc =
      var color = if runtime.argumentCount() < 1:
        DefaultColorScheme[Background]
      else:
        jsToNvg(&runtime.argument(1))

      config.colors[Background] = move(color)
  )

  runtime.defineFn(
    "setTextColor",
    proc =
      var color = if runtime.argumentCount() < 1:
        DefaultColorScheme[Background]
      else:
        jsToNvg(&runtime.argument(1))

      config.colors[Text] = move(color)
  )

  runtime.defineFn(
    "setItemBackgroundColor",
    proc =
      var color = if runtime.argumentCount() < 1:
        DefaultColorScheme[Background]
      else:
        jsToNvg(&runtime.argument(1))

      config.colors[ItemBackground] = move(color)
  )

  runtime.defineFn(
    "setSelectedItemBackgroundColor",
    proc =
      var color = if runtime.argumentCount() < 1:
        DefaultColorScheme[Background]
      else:
        jsToNvg(&runtime.argument(1))

      config.colors[SelectedItemBackground] = move(color)
  )

  runtime.defineFn(
    "setBoundsHitBehaviour",
    proc =
      let behaviour = if runtime.argumentCount() < 1:
        BoundsHitBehaviour.Stay
      else:
        case toLowerAscii(runtime.ToString(&runtime.argument(1)))
        of "stay": BoundsHitBehaviour.Stay
        of "overflow": BoundsHitBehaviour.Overflow
        else: 
          runtime.vm.typeError("Invalid value for bounds-hit behaviour: " & runtime.ToString(&runtime.argument(1)))
          BoundsHitBehaviour.Stay

      config.boundsHit = behaviour
  )

proc loadConfig*(file: string) =
  let parser = newParser(readFile(file))
  let ast = parser.parse()

  let runtime = newRuntime(file, ast)
  runtime.generateConfigProcs()
  runtime.run()
