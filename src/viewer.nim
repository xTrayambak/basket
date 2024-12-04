## Basket viewer/renderer
import std/[os, logging, tables, importutils]
import std/posix except Key
import pkg/[opengl, siwin, nanovg, vmath, pretty]
import pkg/siwin/platforms/wayland/[window, windowOpengl]
import ./[freedesktop, search, usage_history, config, sugar, fonts, argparser]

privateAccess(Window)

type
  Viewer* = object
    entries, originalCopyEntries: seq[DesktopEntry]

    size*: IVec2
    wl*: WindowWaylandOpengl
    vg*: NVGContext
    font*: Font

    input*: Input
    config*: Config

    searchQuery*: string

    selectedIndex*: uint

    alive*: bool = true
    caps*: bool

proc keyToChar*(viewer: Viewer, key: Key): char =
  let caps = 
    viewer.caps or 
    viewer.wl.keyboard.pressed.contains(lshift) or 
    viewer.wl.keyboard.pressed.contains(rshift)

  case key
  of a:
    if caps: return 'A' else: return 'a'
  of b:
    if caps: return 'B' else: return 'b'
  of c:
    if caps: return 'C' else: return 'c'
  of d:
    if caps: return 'D' else: return 'd'
  of e:
    if caps: return 'E' else: return 'e'
  of f:
    if caps: return 'F' else: return 'f'
  of g:
    if caps: return 'G' else: return 'g'
  of h:
    if caps: return 'H' else: return 'h'
  of i:
    if caps: return 'I' else: return 'i'
  of j:
    if caps: return 'J' else: return 'j'
  of k:
    if caps: return 'K' else: return 'k'
  of l:
    if caps: return 'L' else: return 'l'
  of m:
    if caps: return 'M' else: return 'm'
  of n:
    if caps: return 'N' else: return 'n'
  of o:
    if caps: return 'O' else: return 'o'
  of p:
    if caps: return 'P' else: return 'p'
  of q:
    if caps: return 'Q' else: return 'q'
  of r:
    if caps: return 'R' else: return 'r'
  of s:
    if caps: return 'S' else: return 's'
  of t:
    if caps: return 'T' else: return 't'
  of u:
    if caps: return 'U' else: return 'u'
  of v:
    if caps: return 'V' else: return 'v'
  of w:
    if caps: return 'W' else: return 'w'
  of x:
    if caps: return 'X' else: return 'x'
  of y:
    if caps: return 'Y' else: return 'y'
  of z:
    if caps: return 'Z' else: return 'z'
  of n1: return '1'
  of n2: return '2'
  of n3: return '3'
  of n4: return '4'
  of n5: return '5'
  of n6: return '6'
  of n7: return '7'
  of n8: return '8'
  of n9: return '9'
  of n0: return '0'
  of minus: return '-'
  of tilde: return '~'
  of equal: return '='
  of space: return ' '
  else:
    debug "viewer: cannot convert key to character: " & $key
    return '\0'

proc getColor*(viewer: Viewer, category: ColorFor): Color {.inline.} =
  if category in viewer.config.colors: viewer.config.colors[category]
  else: DefaultColorScheme[category]

proc drawEntries*(viewer: var Viewer) =
  var layoutCursor = vec2(0, 64f)

  for i, entry in viewer.entries:
    if i.uint < viewer.selectedIndex:
      continue

    let selected = i.uint == viewer.selectedIndex
    
    viewer.vg.beginPath()
    viewer.vg.roundedRect(x = layoutCursor.x + 8f, y = layoutCursor.y + 4f, w = cfloat(viewer.size.x.float - 16f), h = 32f, r = 8f)
    viewer.vg.fillColor(viewer.getColor(if not selected: ItemBackground else: SelectedItemBackground))
    viewer.vg.fill()
    viewer.vg.closePath()

    viewer.vg.fontFace("sans")
    viewer.vg.fontBlur(0)
    viewer.vg.textAlign(haLeft, vaTop)
    viewer.vg.fillColor(viewer.getColor(Text))
    viewer.vg.fontSize(24f)
    discard viewer.vg.text(layoutCursor.x + 16f, layoutCursor.y + 8f, entry.name)

    layoutCursor = vec2(0, layoutCursor.y + 40)

proc drawSearchDisplay*(viewer: var Viewer) =
  let widthOfBar = viewer.size.x.float - 16f
  viewer.vg.beginPath()
  viewer.vg.roundedRect(x = 8f, y = 8f, w = widthOfBar, h = 48f, r = 12f)
  viewer.vg.fillColor(viewer.getColor(SelectedItemBackground))
  viewer.vg.fill()
  viewer.vg.closePath()

  viewer.vg.fontFace("sans")
  viewer.vg.fontBlur(0)
  viewer.vg.textAlign(haLeft, vaTop)
  viewer.vg.fillColor(viewer.getColor(Text))
  viewer.vg.fontSize(32f)
  discard viewer.vg.text(
    16f, 16f,
    (
      if viewer.searchQuery.len < 1:
        viewer.config.searchPlaceholder
      else:
        viewer.searchQuery
    )
  )

proc draw*(viewer: var Viewer) =
  debug "viewer: drawing viewer"
  glViewport(0, 0, viewer.size.x, viewer.size.y)
  glClearColor(0, 0, 0, 0)
  glClear(GL_COLOR_BUFFER_BIT or
    GL_DEPTH_BUFFER_BIT or
    GL_STENCIL_BUFFER_BIT)
  
  viewer.vg.beginFrame(viewer.size.x.cfloat, viewer.size.y.cfloat, 1f) # TODO: fractional scaling support

  viewer.vg.beginPath()
  viewer.vg.roundedRect(0, 0, viewer.size.x.cfloat, viewer.size.y.cfloat, 16f)
  let color = viewer.getColor(Background)
  viewer.wl.m_transparent = color.a != 255
  viewer.vg.fillColor(color)
  viewer.vg.fill()
  viewer.vg.closePath()
  
  viewer.drawSearchDisplay()
  viewer.drawEntries()

  viewer.vg.endFrame()

proc selectFromSearch*(viewer: var Viewer) =
  var
    indices: Table[string, uint]
    content = newSeq[string](viewer.entries.len)

  let cEntries = viewer.originalCopyEntries
  
  for i, entry in cEntries:
    content[i] = entry.name
    indices[entry.name] = uint(i)

  viewer.entries.reset()

  let ranked = viewer.searchQuery.search(content)
  for rank in ranked:
    viewer.entries &= cEntries[indices[rank]]

proc selectMostUsed*(viewer: var Viewer) =
  var
    indices: Table[DesktopEntry, uint]
    content = newSeq[string](viewer.entries.len)

  let cEntries = viewer.originalCopyEntries

  for i, entry in cEntries:
    content[i] = entry.name
    indices[entry] = uint(i)

  viewer.entries.reset()

  let ranked = cEntries.sortAccordingToUsage()
  for rank in ranked:
    viewer.entries &= cEntries[indices[rank]]

proc redraw*(viewer: var Viewer) {.inline.} =
  debug "viewer: requesting surface redraw (index = " & $viewer.selectedIndex & ')'
  viewer.wl.redraw()
  
proc executeSelectedEntry*(viewer: var Viewer) {.noReturn.} =
  assert(viewer.selectedIndex < viewer.entries.len.uint)
  info "viewer: executing selected entry #" & $viewer.selectedIndex
  let entry = viewer.entries[viewer.selectedIndex.int]

  info "viewer: destroying surface"
  viewer.wl.close()
  viewer.wl.step()

  bumpUsageForEntry(entry)

  info "viewer: executing desktop entry: " & entry.name & " (" & entry.exec & ')'
  
  var 
    program: string
    currArg: string
    args: seq[string]
    writingProgName = true

  for c in entry.exec:
    if writingProgName:
      if c == ' ':
        writingProgName = false
        continue

      program &= c
    else:
      if c == ' ':
        args &= currArg
        reset currArg
        continue

      currArg &= c

  var env: seq[string]
  for key, value in envPairs():
    env &= key & '=' & value

  args &= currArg

  let path = program.findExe()

  info "viewer: finished parsing exec field - allocating cstring array"
  
  var cargs = allocCstringArray(args)
  var cenv = allocCstringArray(env)
  
  var pid: Pid
  var x: Tposix_spawn_file_actions
  var y: Tposix_spawnattr
  if posix_spawn(pid, path.cstring, x, y, cargs, cenv) != 0:
    error "viewer: failed to spawn program! (path=" & path & ", error=" & $strerror(errno) & " (" & $errno & ')'
  
  info "viewer: cleaning up for exit - freeing `cargs` and `cenv`"
  deallocCstringArray(cargs)
  deallocCstringArray(cenv)
  quit(0)

proc validKeyPress*(event: KeyEvent): bool {.inline.} =
  event.pressed or event.repeated

proc runBasketViewer*(input: sink Input, entries: sink seq[DesktopEntry]): Viewer =
  info "viewer: initializing viewer"
  var viewer: Viewer
  viewer.size = ivec2(640, 480)
  viewer.input = move(input)

  info "viewer: creating surface"
  var wl = newOpenglWindowWayland(
    size = viewer.size,
    kind = WindowWaylandKind.LayerSurface,
    namespace = "basket",
    layer = Layer.Overlay
  )
  wl.m_transparent = true

  info "viewer: loading OpenGL"
  loadExtensions()

  nvgInit(glGetProc)
  viewer.vg = nvgCreateContext({nifAntialias})
  
  wl.setAnchor(@[LayerEdge.Top, LayerEdge.Bottom, LayerEdge.Left, LayerEdge.Right])
  wl.setKeyboardInteractivity(LayerInteractivityMode.Exclusive)
  viewer.entries = move(entries)
  viewer.originalCopyEntries = deepCopy(viewer.entries)
  viewer.wl = move(wl)
  viewer.selectedIndex = 0'u
  viewer.config = config.getConfig()
  viewer.font = viewer.vg.createFont("sans", &getFontPath(viewer.config.font))
  viewer.selectMostUsed()

  viewer.wl.eventsHandler.onKey = proc(event: KeyEvent) =
    if event.key == escape:
      debug "viewer: exiting as user pressed Esc"
      viewer.wl.close()
      return

    if event.key == down and event.validKeyPress():
      debug "viewer: Going down"
      if (viewer.selectedIndex + 1) > viewer.entries.len.uint:
        case viewer.config.boundsHit
        of BoundsHitBehaviour.Stay:
          debug "viewer: can't go further down, ignoring."
          return
        of BoundsHitBehaviour.Overflow:
          debug "viewer: can't go further down, overflowing."
          viewer.selectedIndex = 0'u
          viewer.redraw()
          return

      inc viewer.selectedIndex
      
      viewer.redraw()
      return

    if event.key == up and event.validKeyPress():
      debug "viewer: going up"
      if viewer.selectedIndex < 1:
        case viewer.config.boundsHit
        of BoundsHitBehaviour.Stay:
          debug "viewer: can't go further up, ignoring."
          return
        of BoundsHitBehaviour.Overflow:
          debug "viewer: can't go further up, overflowing."
          viewer.selectedIndex = uint(viewer.entries.len - 1)
          viewer.redraw()
          return

      dec viewer.selectedIndex

      viewer.redraw()
      return

    if event.key == enter and not event.pressed:
      viewer.executeSelectedEntry()

    if event.key == capsLock and event.validKeyPress():
      viewer.caps = not viewer.caps
      return

    if event.key == backspace and event.validKeyPress():
      if viewer.searchQuery.len < 1: # if search buffer is empty, rank according to usage
        debug "viewer: ignoring backspace as query buffer is empty"
        viewer.selectMostUsed()
        viewer.redraw()
      else:
        viewer.searchQuery = viewer.searchQuery[0 ..< viewer.searchQuery.len - 1]
        debug "viewer: search query is now: " & viewer.searchQuery
        viewer.selectFromSearch()
        viewer.redraw()

    if event.validKeyPress() and (let c = viewer.keyToChar(event.key); c != '\0'):
      viewer.searchQuery &= c
      debug "viewer: search query is now: " & viewer.searchQuery
      viewer.selectFromSearch()
      viewer.redraw()

  viewer.wl.eventsHandler.onRender = proc(event: RenderEvent) =
    viewer.draw()
  
  viewer.wl.run()
