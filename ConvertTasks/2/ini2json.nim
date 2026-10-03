import std/[os, strutils, json]

proc stripComment(s: string): string =
  for i in 0 ..< s.len:
    if (s[i] == ';' or s[i] == '#') and (i == 0 or s[i - 1] in {' ', '\t'}):
      return s[0 ..< i].strip()
  s

proc inferValue(raw: string): JsonNode =
  case raw.toLowerAscii
  of "true", "yes", "on": return newJBool(true)
  of "false", "no", "off": return newJBool(false)
  of "null", "nil": return newJNull()
  else: discard

  if raw.len > 1 and raw[0] == '0' and raw[1] in Digits:
    return newJString(raw)

  try: return newJInt(parseBiggestInt(raw))
  except ValueError: discard
  try: return newJFloat(parseFloat(raw))
  except ValueError: discard

  newJString(raw)

let input = if paramCount() > 0: paramStr(1) else: "example.ini"
if not fileExists(input):
  quit("ini2json: файл не найден: " & input, 1)

let output = input.changeFileExt("json")
let root = newJObject()
var current = root

for rawLine in lines(input):
  let line = rawLine.strip()
  if line.len == 0 or line[0] == ';' or line[0] == '#':
    continue

  if line[0] == '[':
    let close = line.find(']')
    if close < 0:
      continue
    current = newJObject()
    root[line[1 ..< close].strip()] = current
    continue

  let sep = line.find('=')
  if sep < 0:
    continue

  let key = line[0 ..< sep].strip()
  let value = line[sep + 1 .. ^1].strip()

  if value.len >= 2 and value[0] == '"' and value[^1] == '"':
    current[key] = newJString(value[1 ..< value.len - 1])
  else:
    current[key] = inferValue(value.stripComment)

writeFile(output, pretty(root, 2) & "\n")
echo "Готово -> ", output
