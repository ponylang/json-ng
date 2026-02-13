"""
Immutable JSON library for Pony.

Provides immutable JSON value types backed by persistent collections, with
three levels of navigation (JsonNav for simple chaining, JsonLens for
composable paths, JSONPath for string-based queries), a layered parser
(token parser underneath, full parser on top), and efficient construction
via chained updates on val types.

## Quick Start

Build JSON:
```pony
let doc = JsonObject
  .update("name", "Alice")
  .update("age", I64(30))
```

Parse JSON:
```pony
match JsonParser.parse(source)
| let json: JsonType =>
  let nav = JsonNav(json)
  try
    let name = nav("name").as_string()?
  end
| let err: JsonParseError =>
  env.err.print(err.string())
end
```
"""

use "collections/persistent"

type JsonType is (JsonObject | JsonArray | String | I64 | F64 | Bool | JsonNull)

primitive JsonNull is Stringable
  """
  JSON null value.

  Distinct from Pony's None to avoid conflicts with persistent collections
  that use None as a 'not found' sentinel.
  """

  fun string(): String iso^ => "null".clone()
