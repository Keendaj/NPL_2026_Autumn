import std.algorithm : canFind, map, sort;
import std.array : appender, join, replace;
import std.conv : to;
import std.format : format;
import std.json;
import std.path : setExtension;
import std.stdio;

static import std.file;

struct Row
{
    string[] keys;
    string[string] values;

    void add(string key, string value)
    {
        if (key !in values)
            keys ~= key;
        values[key] = value;
    }
}

string scalarText(JSONValue node)
{
    switch (node.type)
    {
    case JSONType.null_:    return "";
    case JSONType.true_:    return "true";
    case JSONType.false_:   return "false";
    case JSONType.string:   return node.str;
    case JSONType.integer:  return node.integer.to!string;
    case JSONType.uinteger: return node.uinteger.to!string;
    case JSONType.float_:   return format("%.15g", node.floating);
    default:                return node.toString();
    }
}

void flatten(JSONValue node, string prefix, ref Row row)
{
    if (node.type == JSONType.null_)
        return;

    if (node.type == JSONType.object)
    {
        auto keys = node.object.keys;
        sort(keys);
        foreach (key; keys)
            flatten(node[key], prefix.length ? prefix ~ "." ~ key : key, row);
    }
    else if (node.type == JSONType.array)
    {
        string[] parts;
        foreach (item; node.array)
            parts ~= scalarText(item);
        row.add(prefix, parts.join(";"));
    }
    else
        row.add(prefix, scalarText(node));
}

string quoteField(string value)
{
    if (!value.canFind(',') && !value.canFind('"') && !value.canFind('\n'))
        return value;
    return "\"" ~ value.replace("\"", "\"\"") ~ "\"";
}

int main(string[] args)
{
    string input = args.length > 1 ? args[1] : "example.json";
    if (!std.file.exists(input))
    {
        stderr.writeln("json2csv: файл не найден: ", input);
        return 1;
    }

    JSONValue root;
    try
        root = parseJSON(std.file.readText(input));
    catch (JSONException e)
    {
        stderr.writeln("json2csv: некорректный JSON: ", e.msg);
        return 1;
    }

    Row[] rows;
    if (root.type == JSONType.array)
    {
        foreach (item; root.array)
        {
            Row row;
            flatten(item, "", row);
            rows ~= row;
        }
    }
    else
    {
        Row row;
        flatten(root, "", row);
        rows ~= row;
    }

    string[] columns;
    foreach (row; rows)
        foreach (key; row.keys)
            if (!columns.canFind(key))
                columns ~= key;

    auto sink = appender!string;
    sink.put(columns.map!quoteField.join(",") ~ "\n");
    foreach (row; rows)
        sink.put(columns.map!(c => quoteField(c in row.values ? row.values[c] : "")).join(",") ~ "\n");

    string output = input.setExtension("csv");
    std.file.write(output, sink.data);
    writeln("Готово -> ", output);
    return 0;
}
