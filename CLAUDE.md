# json-ng

Immutable JSON library for Pony, exploring a design for potential stdlib inclusion.

## Building and Testing

```bash
make                    # build tests + examples (release)
make test               # same as above
make config=debug       # debug build
make build-examples     # examples only
make clean              # clean build artifacts + corral cache
```

## Project Status

**Current state**: All features compile and run. Comprehensive test suite with 20 property-based tests (PonyCheck) and 48 example-based tests.

**What's implemented**:
- Immutable JSON value types (`JsonObject`, `JsonArray`, `JsonNull`) backed by persistent collections (CHAMP Map, HAMT Vec)
- Three access patterns: `JsonNav` (chained read-only), `JsonLens` (composable read/write/remove paths), `JsonPath` (RFC 9535 string-based queries)
- Layered parser: `JsonTokenParser` (streaming tokens) → `JsonParser` (full tree)
- Serialization: compact and pretty-printed output
- Example program demonstrating all features

**What's NOT implemented**:
- No known gaps — all planned RFC 9535 features are implemented

## Architecture

### Core Types (`json/json.pony`)

```pony
type JsonValue is (JsonObject | JsonArray | String | I64 | F64 | Bool | JsonNull)
```

All JSON values are `val`. Construction is via chained method calls that return new values with structural sharing.

### Why `JsonNull` instead of `None`

Pony's persistent `HashMap` uses `None` as an internal "key not found" sentinel (in `_MapSubNodes.apply`). When `V` includes `None` (as it would if `JsonValue` used `None` for JSON null), the HAMT can't distinguish "key not found" from "value is null":

- `HashMap.apply` returns `None` instead of raising for missing keys
- `HashMap.contains` returns `false` for keys that map to `None`
- `HashMap.get_or_else` returns `None` instead of the alt value for missing keys

We use `JsonNull` (a distinct primitive) so that `None` never appears as a stored value in the persistent Map.

**Related issue**: https://github.com/ponylang/ponyc/issues/4833

With `JsonNull`, Pony's `None` serves its natural role: "no result yet" in `_TreeBuilder` and "delete this path" in lens `remove` operations.

### File Layout

**Public API** (in `json/`):

| File | Contents |
|------|----------|
| `json.pony` | Package docstring, `JsonValue` union, `JsonNull` |
| `json_object.pony` | `JsonObject` — immutable object backed by `pc.Map` |
| `json_array.pony` | `JsonArray` — immutable array backed by `pc.Vec` |
| `json_nav.pony` | `JsonNav` — chained read-only navigation |
| `json_lens.pony` | `JsonLens` — composable paths with get/set/remove |
| `json_parser.pony` | `JsonParser` — high-level parser (errors as data) |
| `json_token_parser.pony` | `JsonTokenParser` — streaming token parser |
| `json_token.pony` | `JsonToken` union type |
| `json_token_notify.pony` | `JsonTokenNotify` interface |
| `json_parse_error.pony` | `JsonParseError` |
| `json_path.pony` | `JsonPath`, `JsonPathParser`, `JsonPathParseError` |
| `json_not_found.pony` | `JsonNotFound` sentinel |

**Internal** (in `json/`):

| File | Contents |
|------|----------|
| `_test.pony` | Test suite (20 property + 48 example tests) |
| `_tree_builder.pony` | Assembles token events into `JsonValue` tree |
| `_json_print.pony` | Serialization (compact + pretty) |
| `_traversal.pony` | Lens traversal trait and implementations |
| `_json_path_parser.pony` | Recursive descent JSONPath parser |
| `_json_path_selector.pony` | `_NameSelector`, `_IndexSelector`, `_WildcardSelector`, `_SliceSelector`, `_FilterSelector` |
| `_json_path_segment.pony` | `_ChildSegment`, `_DescendantSegment` |
| `_json_path_eval.pony` | JSONPath evaluation pipeline |
| `_json_path_filter.pony` | Filter expression AST types |
| `_json_path_filter_eval.pony` | Filter expression evaluator (`_FilterEval`, `_FilterCompare`) |
| `_mort.pony` | `_Unreachable` panic primitive for impossible code paths |
| `_i_regexp.pony` | `_IRegexp` compiled pattern, `_IRegexpParseError`, `_IRegexpCompiler` entry point |
| `_i_regexp_ast.pony` | `_RegexNode` union type and AST node classes |
| `_i_regexp_parser.pony` | `_IRegexpParser` recursive descent parser (RFC 9485) |
| `_i_regexp_nfa.pony` | `_NFA`, `_NFABuilder`, Thompson NFA construction |
| `_i_regexp_exec.pony` | `_NFAExec` simulation, `_StateSet`, `_RangeMatcher` |
| `_unicode_categories.pony` | Unicode 16.0 General Category range tables, `_UnicodeCategories` lookup, `_RangeOps` |

### Access Pattern Comparison

- **`JsonNav`**: Wraps a specific value. Read-only. One-shot chained access. JsonNotFound propagates through chains. Good for "grab this one thing."
- **`JsonLens`**: Describes a reusable path (not tied to a value). Supports get/set/remove. Composable via `compose` and `or_else`. Good for "define a path once, apply to many documents."
- **`JsonPath`**: String-based query language (RFC 9535 subset). Can match multiple values via wildcards, recursive descent, slicing. Returns arrays of results. Good for "find all prices in the document."

## Pony-Specific Issues Encountered

These came up during prototyping and are worth knowing:

1. **`val` constructors can't take `ref` parameters**: `new val create(iter: Iterator[T])` won't compile because `Iterator` is `ref` (not sendable).

2. **`Stringable.string()` is `fun box`, not `fun val`**: `JsonObject` and `JsonArray` implement `Stringable`, so `string()` receives `this` as `box`. But `_JsonPrint._value` needs `val` for union matching. Solution: separate entry points (`compact_object`/`pretty_object`) that accept `box`, while internal recursion uses `val` (values from persistent collection iteration are `val` through viewpoint adaptation).

3. **`recover val` blocks and `ref` locals**: The JSONPath evaluator builds arrays as `ref` inside a `recover val` block. All `ref` locals must be created AND consumed within the block.

4. **`F64.string()` returns `String iso^`**: Must explicitly type as `let s: String = n.string()` to convert `iso^` to `val`.

## Design Documents

The original design plans from the prototype phase are at:
- `~/investigations/json-for-pony/PLAN.md` — Original library design
- `~/investigations/json-for-pony/PLAN-JSON-PATH.md` — JSONPath feature design
