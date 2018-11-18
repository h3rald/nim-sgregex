{.compile: "libregex.c".}

#const 
#  RXSUCCESS = 0
#  RXEINMOD = - 1
#  RXEPART = - 2
#  RXEUNEXP = - 3
#  RXERANGE = - 4
#  RXELIMIT = - 5
#  RXEEMPTY = - 6
#  RXENOREF = - 7
#  RX_ALLMODS = "mis"

type 
  srx_MemFunc = proc (a2: pointer; a3: pointer; a4: csize): pointer
  srx_Context = pointer

proc RX_STRLENGTHFUNC(str: string): int = 
  return str.len

{.push importc.}
proc srx_CreateExt(str: cstring; strsize: csize; mods: cstring; errnpos: ptr cint; memfn: srx_MemFunc; memctx: pointer): ptr srx_Context

template srx_Create(str, mods: string): ptr srx_Context = 
  srx_CreateExt(str, RX_STRLENGTHFUNC(str), mods, nil, nil, nil)

proc srx_Destroy(R: ptr srx_Context): cint

# proc srx_DumpToStdout(R: ptr srx_Context)

proc srx_MatchExt(R: ptr srx_Context; str: cstring; size: csize; offset: csize): cint

template srx_Match(R: ptr srx_Context, str: cstring, off: csize): cint = 
  srx_MatchExt(R, str, RX_STRLENGTHFUNC(str), off)

proc srx_GetCaptureCount(R: ptr srx_Context): cint

proc srx_GetCaptured(R: ptr srx_Context; which: cint; pbeg: ptr csize; pend: ptr csize): cint

#proc srx_GetCapturedPtrs(R: ptr srx_Context; which: cint; pbeg: cstringArray; pend: cstringArray): cint

proc srx_ReplaceExt(R: ptr srx_Context; str: cstring; strsize: csize; rep: cstring; repsize: csize; outsize: ptr csize): cstring

template srx_Replace(R: ptr srx_Context, str: cstring, rep: cstring): cstring = 
  srx_ReplaceExt(R, str, RX_STRLENGTHFUNC(str), rep, RX_STRLENGTHFUNC(rep), nil)

# proc srx_FreeReplaced(R: ptr srx_Context; repstr: cstring)

{.pop.}

# Public Library

import strutils

type 
  InvalidRegexError = ref Exception

proc newRegex(pattern, mods: string): ptr srx_Context =
  result = srx_Create(pattern, mods)
  if result.isNil:
    raise(InvalidRegexError(msg: "Invalid regular expression: \"$1\"" % pattern))

proc match*(str, pattern, mods: string): bool =
  let r = newRegex(pattern, mods)
  result = srx_Match(r, str, 0) == 1
  discard srx_Destroy(r)

proc match*(str, pattern: string): bool =
  return match(str, pattern, "")

proc search*(str, pattern, mods: string): seq[string] =
  let r = newRegex(pattern, mods)
  discard srx_Match(r, str, 0) == 1
  let count = srx_GetCaptureCount(r)
  result = newSeq[string](count)
  for i in 0..count-1:
    var first = 0
    var last = 0
    discard srx_GetCaptured(r, i, addr first, addr last)
    result[i] = str.substr(first, last-1)
  discard srx_Destroy(r)

proc search*(str, pattern: string): seq[string] =
  return search(str, pattern, "")

proc replace*(str, pattern, repl, mods: string): string =
  var r = newRegex(pattern, mods)
  result = $srx_Replace(r, str, repl)
  discard srx_Destroy(r)

proc replace*(str, pattern, repl: string): string =
  return replace(str, pattern, repl, "")

proc `=~`*(str, r: string): seq[string] =
  let m = r.search("(s)?/(.+?)/((.+?)/)?([mis]{0,3})?")
  # full match, s, reg, replace/, replace, flags
  if m[1] == "s" and m[3] != "":
    return @[replace(str, m[2], m[4], m[5])]
  else:
    return search(str, m[2], m[5])

when isMainModule:

  proc tmatch(str, pattern: string) =
    echo str, " =~ ", "/", pattern, "/", " -> ", str.match(pattern)

  proc tsearch(str, pattern: string) =
    echo str, " =~ ", "/", pattern, "/", " -> ", str.search(pattern)

  proc tsearch(str, pattern, mods: string) =
    echo str, " =~ ", "/", pattern, "/", mods, " -> ", str.search(pattern, mods)

  proc treplace(str, pattern, repl: string) =
    echo str, " =~ ", "s/", pattern, "/", repl, "/", " -> ", str.replace(pattern, repl)

  proc toperator(str, pattern: string) =
    echo str, " =~ ", pattern, " -> ", str =~ pattern

  "HELLO".tmatch("^H(.*)O$")
  "HELLO".tmatch("^H(.*)S$")
  "HELLO".tsearch("^H(E)(.*)O$")
  "Hello, World!".treplace("[a-zA-Z]+,", "Goodbye,")
  "127.0.0.1".tsearch("^([0-9]{1,3})\\.([0-9]{1,3})\\.([0-9]{1,3})\\.([0-9]{1,3})$")
  "127.0.0.1".treplace("^([0-9]{1,3})\\.([0-9]{1,3})\\.([0-9]{1,3})\\.([0-9]{1,3})$", "$4.$3.$1.$2")
  "127.0.0.1".treplace("[0-9]+", "255")
  "Hello".tsearch("HELLO", "i")
  "Hello\nWorld!".tsearch("HELLO.WORLD", "mis")
  "Testing".toperator("s/test/eat/i")
