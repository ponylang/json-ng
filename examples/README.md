# Examples

Each subdirectory is a self-contained Pony program demonstrating a different
part of the json-ng library. Ordered from simplest to most involved.

## [actors](actors/)

Builds a nested `JsonObject`, passes it to a behavior, then queries it using
both `JsonNav` chained navigation and `JsonPathParser` compiled queries.
Demonstrates that JSON values are `val` and can be safely shared across actor
boundaries.

## [collections-integration](collections-integration/)

Uses `JsonValue` as the value type in a stdlib `Map` with `iso` arrays,
demonstrating that JSON values compose with Pony's standard collections and
reference capabilities. Accumulates `JsonObject` errors per file using
`Map.upsert` with `iso` array values.

## [basic](basic/)

Walks through all major library features: building JSON values, parsing from
strings, navigating with `JsonNav`, reading and modifying with `JsonLens`,
and querying with `JsonPath` including wildcards, slices, filters, and
function extensions. Start here if you're new to the library.
