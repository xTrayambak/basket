import std/[logging, strutils, options]

{.passC: gorge("pkg-config --cflags fontconfig --cflags").strip().}
{.passL: gorge("pkg-config --cflags fontconfig --libs").strip().}

{.emit: """
#include <fontconfig/fontconfig.h>
#include <string.h>
#include <assert.h>

extern "C" char* libbasket_get_font(char *name)
{
  if (!FcInit())
    return NULL;

  FcPattern *pattern = FcPatternCreate();
  if (!pattern) 
    return NULL;

  FcPatternAddInteger(pattern, FC_WEIGHT, FC_WEIGHT_NORMAL);
  
  FcObjectSet *os = FcObjectSetBuild(FC_FAMILY, FC_STYLE, FC_FILE, NULL);
  if (!os)
    return NULL;

  FcFontSet *fs = FcFontList(NULL, pattern, os);
  if (!fs)
    return NULL;

  char *values = NULL;
  size_t size = 0;

  for (int i = 0; i < fs->nfont; i++)
  {
    FcChar8 *family;
    FcChar8 *file;

    if (FcPatternGetString(fs->fonts[i], FC_FAMILY, 0, &family) == FcResultMatch && strcmp(family, name) == 0)
    {
      if (FcPatternGetString(fs->fonts[i], FC_FILE, 0, &file) == FcResultMatch)
        return file;
    }
  }

  if (fs->nfont > 0)
  {
    FcChar8 *file;
    if (FcPatternGetString(fs->fonts[0], FC_FILE, 0, &file) == FcResultMatch)
      return file; // As a last ditch attempt, return any font.
  }
}
""".}

proc libbasket_get_font(name: cstring): cstring {.importc, cdecl.}
proc getFontPath*(name: string): Option[string] =
  let value = libbasket_get_font(name.cstring)
  echo value == nil
  info "basket: using font: " & $value
  if value.len > 0:
    return some($value)
