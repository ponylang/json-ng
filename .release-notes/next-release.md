## Add slice-with-step support to JSONPath

JSONPath slice expressions now support the optional step parameter from RFC 9535: `[start:end:step]`. The step controls which elements are selected and in what order.

```pony
let doc = JsonArray.push(I64(0)).push(I64(1)).push(I64(2))
  .push(I64(3)).push(I64(4))

// Every other element
let evens = JsonPathParser.compile("$[::2]")?
evens.query(doc) // [0, 2, 4]

// Reverse the array
let rev = JsonPathParser.compile("$[::-1]")?
rev.query(doc) // [4, 3, 2, 1, 0]

// Every other element in reverse
let rev2 = JsonPathParser.compile("$[::-2]")?
rev2.query(doc) // [4, 2, 0]
```

Positive steps select forward, negative steps select in reverse, and step=0 produces no results. When step is omitted, the existing behavior (step=1) is unchanged.

## Add filter expression support to JSONPath

JSONPath queries now support filter expressions (`?`) per RFC 9535 Section 2.3.5.1. Filters select array elements or object values that satisfy a logical condition.

```pony
let doc = JsonParser.parse(
  """
  {"books":[{"title":"A","price":8},{"title":"B","price":15}]}
  """)?

// Comparison: books under $10
let cheap = JsonPathParser.compile("$.books[?@.price < 10]")?
cheap.query(doc) // [{"title":"A","price":8}]

// Existence: select elements where a key is present
let has_title = JsonPathParser.compile("$.books[?@.title]")?
has_title.query(doc) // both books

// Logical operators: && (and), || (or), ! (not)
let combined = JsonPathParser.compile(
  "$.books[?@.price < 10 && @.title == 'A']")?

// Absolute query ($) references the document root inside filters
let by_default = JsonPathParser.compile(
  "$.items[?@.type == $.default_type]")?
```

Supported filter features:

* Comparison operators: `==`, `!=`, `<`, `<=`, `>`, `>=`
* Logical operators: `&&`, `||`, `!` with parenthesized grouping
* Current node (`@`) and root (`$`) references
* Literal values: strings, integers, floats, booleans, null
* Existence tests (including non-singular queries like `@[*]`, `@..name`)
* Nested filters
* RFC 9535 semantics: missing keys produce "Nothing" (not null), no type coercion, mixed I64/F64 comparison converts to F64

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

## Rename NotFound to JsonNotFound

The `NotFound` sentinel type has been renamed to `JsonNotFound` for consistency with the library's naming convention (`JsonObject`, `JsonArray`, `JsonNull`, etc.).

Before:

```pony
match lens.get(doc)
| let v: json.JsonValue => // use v
| json.NotFound => // handle missing
end
```

After:

```pony
match lens.get(doc)
| let v: json.JsonValue => // use v
| json.JsonNotFound => // handle missing
end
```

## Rename JsonType to JsonValue

The `JsonType` type alias has been renamed to `JsonValue` for clarity — it names a value, not a type category.

Before:

```pony
match JsonParser.parse(source)
| let j: json.JsonType => // use j
| let err: json.JsonParseError => // handle error
end
```

After:

```pony
match JsonParser.parse(source)
| let j: json.JsonValue => // use j
| let err: json.JsonParseError => // handle error
end
```

