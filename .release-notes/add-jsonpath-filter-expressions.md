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

Function extensions (`length()`, `count()`, `match()`, etc.) are not yet supported.
