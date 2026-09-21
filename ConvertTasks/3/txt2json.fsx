open System
open System.IO
open System.Text
open System.Globalization

type Value =
    | VNull
    | VBool  of bool
    | VInt   of int64
    | VFloat of float
    | VStr   of string
    | VList  of Value list
    | VObj   of (string * Value) list

type Record = { Kind: string; Name: string; Fields: (string * Value) list }

let parseScalar (raw: string) : Value =
    match raw.ToLowerInvariant() with
    | "yes" | "true"  | "on"  -> VBool true
    | "no"  | "false" | "off" -> VBool false
    | "null" | "none" | "-"   -> VNull
    | _ ->
        match Int64.TryParse(raw, NumberStyles.Integer, CultureInfo.InvariantCulture) with
        | true, i -> VInt i
        | _ ->
            match Double.TryParse(raw, NumberStyles.Float, CultureInfo.InvariantCulture) with
            | true, f -> VFloat f
            | _ -> VStr raw

let (|Pair|_|) (s: string) =
    let i = s.IndexOf '='
    if i > 0 then Some(s.Substring(0, i).Trim(), s.Substring(i + 1).Trim()) else None

let parseValue (raw: string) : Value =
    if raw.Length >= 2 && raw.StartsWith "\"" && raw.EndsWith "\"" then
        VStr(raw.Substring(1, raw.Length - 2))
    elif raw.Contains "," then
        let parts =
            raw.Split(',')
            |> Array.map (fun p -> p.Trim())
            |> Array.filter (fun p -> p <> "")
            |> Array.toList
        let isPair p = match p with Pair _ -> true | _ -> false
        if not parts.IsEmpty && parts |> List.forall isPair then
            VObj [ for p in parts do
                     match p with
                     | Pair (k, v) -> yield k, parseScalar v
                     | _ -> () ]
        else
            VList(parts |> List.map parseScalar)
    else
        match raw with
        | Pair (k, v) -> VObj [ k, parseScalar v ]
        | _ -> parseScalar raw

let (|Blank|Comment|Meta|Field|Header|) (line: string) =
    let t = line.Trim()
    if t = "" then Blank
    elif t.StartsWith "#" then Comment
    elif t.StartsWith "@" then
        let body = t.Substring 1
        let i = body.IndexOf ' '
        if i < 0 then Meta(body, "") else Meta(body.Substring(0, i), body.Substring(i + 1).Trim())
    elif (line.StartsWith " " || line.StartsWith "\t") && t.Contains ":" then
        let i = t.IndexOf ':'
        Field(t.Substring(0, i).Trim(), t.Substring(i + 1).Trim())
    else
        let parts = t.Split([| ' ' |], 2)
        Header(parts.[0].Trim(), (if parts.Length > 1 then parts.[1].Trim() else ""))

let escape (s: string) =
    let sb = StringBuilder()
    for c in s do
        match c with
        | '"'  -> sb.Append "\\\"" |> ignore
        | '\\' -> sb.Append "\\\\" |> ignore
        | '\n' -> sb.Append "\\n"  |> ignore
        | '\r' -> sb.Append "\\r"  |> ignore
        | '\t' -> sb.Append "\\t"  |> ignore
        | c -> sb.Append c |> ignore
    sb.ToString()

let rec render (sb: StringBuilder) (level: int) (value: Value) =
    let pad n = "\n" + String(' ', n * 2)
    match value with
    | VNull    -> sb.Append "null" |> ignore
    | VBool b  -> sb.Append(if b then "true" else "false") |> ignore
    | VInt i   -> sb.Append(i.ToString(CultureInfo.InvariantCulture)) |> ignore
    | VFloat f -> sb.Append(f.ToString("R", CultureInfo.InvariantCulture)) |> ignore
    | VStr s   -> sb.Append('"').Append(escape s).Append('"') |> ignore
    | VList [] -> sb.Append "[]" |> ignore
    | VObj  [] -> sb.Append "{}" |> ignore
    | VList items ->
        sb.Append '[' |> ignore
        items |> List.iteri (fun i item ->
            if i > 0 then sb.Append ',' |> ignore
            sb.Append(pad (level + 1)) |> ignore
            render sb (level + 1) item)
        sb.Append(pad level).Append ']' |> ignore
    | VObj fields ->
        sb.Append '{' |> ignore
        fields |> List.iteri (fun i (key, item) ->
            if i > 0 then sb.Append ',' |> ignore
            sb.Append(pad (level + 1)) |> ignore
            sb.Append('"').Append(escape key).Append("\": ") |> ignore
            render sb (level + 1) item)
        sb.Append(pad level).Append '}' |> ignore

let input =
    match fsi.CommandLineArgs |> Array.toList |> List.tail with
    | path :: _ -> path
    | [] -> "players.txt"

if not (File.Exists input) then
    eprintfn "txt2json: файл не найден: %s" input
    exit 1

let mutable meta: (string * Value) list = []
let mutable records: Record list = []
let mutable current: Record option = None

let flush () =
    match current with
    | Some r -> records <- { r with Fields = List.rev r.Fields } :: records
    | None -> ()

for line in File.ReadLines input do
    match line with
    | Blank | Comment -> ()
    | Meta (key, value) -> meta <- (key, parseValue value) :: meta
    | Field (key, value) ->
        match current with
        | Some r -> current <- Some { r with Fields = (key, parseValue value) :: r.Fields }
        | None -> ()
    | Header (kind, name) ->
        flush ()
        current <- Some { Kind = kind; Name = name; Fields = [] }

flush ()
let parsed = List.rev records

let recordValue (r: Record) = VObj(("name", VStr r.Name) :: r.Fields)

let groups =
    parsed
    |> List.map (fun r -> r.Kind)
    |> List.distinct
    |> List.map (fun kind ->
        kind + "s", VList(parsed |> List.filter (fun r -> r.Kind = kind) |> List.map recordValue))

let document = VObj(("meta", VObj(List.rev meta)) :: groups)

let sb = StringBuilder()
render sb 0 document

let output = Path.ChangeExtension(input, ".json")
File.WriteAllText(output, sb.ToString() + "\n", UTF8Encoding false)
printfn "Готово -> %s" output
