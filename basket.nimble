# Package

version       = "0.1.0"
author        = "xTrayambak"
description   = "Sift through your basket of apps with ease"
license       = "GPL-3.0-or-later"
srcDir        = "src"
bin           = @["basket"]


# Dependencies

requires "nim >= 2.0.0"
requires "iniplus >= 0.3.3"
requires "pretty <= 0.2.0"
requires "opengl >= 1.2.9"
requires "siwin#9ce9aa3efa84f55bbf3d29ef0517b2411d08a357"
requires "nanovg >= 0.4.0"
requires "vmath >= 2.0.0"
requires "fuzzy >= 0.1.0"
requires "colored_logger >= 0.1.0"

requires "jsony >= 1.1.5"