## Add function extension support to JSONPath

JSONPath filter expressions now support the five built-in function extensions defined in RFC 9535 Section 2.4.

```pony
let doc = JsonParser.parse(
  """
  {"items":[{"name":"Alice","tags":["admin"]},{"name":"Bob","tags":["user","dev"]}]}
  """)?

// match(): full-string I-Regexp match
let admins = JsonPathParser.compile(
  """$.items[?match(@.name, "A.*")]""")?
admins.query(doc) // [{"name":"Alice","tags":["admin"]}]

// search(): substring I-Regexp search
let has_b = JsonPathParser.compile(
  """$.items[?search(@.name, "b")]""")?

// length(): string codepoint count, array/object size
let short_names = JsonPathParser.compile(
  "$.items[?length(@.name) <= 3]")?
short_names.query(doc) // [{"name":"Bob",...}]

// count(): nodelist cardinality
let multi_tag = JsonPathParser.compile(
  "$.items[?count(@.tags[*]) > 1]")?

// value(): extract single value from nodelist
let first_tag = JsonPathParser.compile(
  """$.items[?value(@.tags[0]) == "admin"]""")?
```

Supported functions:

* `match(value, pattern)` — full-string I-Regexp match (returns LogicalType)
* `search(value, pattern)` — substring I-Regexp search (returns LogicalType)
* `length(value)` — Unicode scalar value count for strings, element/member count for arrays/objects (returns ValueType)
* `count(query)` — number of nodes selected by a query (returns ValueType)
* `value(query)` — the single value from a nodelist, or Nothing if 0 or 2+ nodes (returns ValueType)

Type system enforcement per RFC 9535: LogicalType functions (`match`, `search`) can only appear as standalone test expressions or negated with `!`. ValueType functions (`length`, `count`, `value`) can only appear in comparisons. Invalid usage produces a clear parse error.
