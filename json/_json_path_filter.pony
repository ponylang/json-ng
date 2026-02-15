// Filter expression AST types for JSONPath (RFC 9535 Section 2.3.5).
//
// These types represent the parsed filter expression tree stored inside
// _FilterSelector. All types are val — constructed at parse time and
// evaluated immutably against JSON documents.

primitive _Nothing
  """
  Represents the absence of a value from a singular query result.

  Distinct from `JsonNull` (JSON null) per RFC 9535: a missing key yields
  `_Nothing`, while a key mapped to `null` yields `JsonNull`. Two Nothings
  compare equal; Nothing compared to any value is false (except `!=`).
  """

// The result of evaluating a singular query: either a value or absence.
type _QueryResult is (JsonType | _Nothing)

// --- Comparison operators ---

primitive _CmpEq
primitive _CmpNeq
primitive _CmpLt
primitive _CmpLte
primitive _CmpGt
primitive _CmpGte

type _ComparisonOp is
  (_CmpEq | _CmpNeq | _CmpLt | _CmpLte | _CmpGt | _CmpGte)

// --- Singular segments (name/index only, no wildcards/slices/descendants) ---

class val _SingularNameSegment
  """Select an object member by key in a singular query."""
  let name: String

  new val create(name': String) =>
    name = name'

class val _SingularIndexSegment
  """Select an array element by index in a singular query."""
  let index: I64

  new val create(index': I64) =>
    index = index'

type _SingularSegment is (_SingularNameSegment | _SingularIndexSegment)

// --- Singular queries (used in comparisons) ---

class val _RelSingularQuery
  """Singular query relative to the current node (@)."""
  let segments: Array[_SingularSegment] val

  new val create(segments': Array[_SingularSegment] val) =>
    segments = segments'

class val _AbsSingularQuery
  """Singular query relative to the document root ($)."""
  let segments: Array[_SingularSegment] val

  new val create(segments': Array[_SingularSegment] val) =>
    segments = segments'

type _SingularQuery is (_RelSingularQuery | _AbsSingularQuery)

// --- Comparables (what can appear on either side of a comparison) ---
// Expands to: String | I64 | F64 | Bool | JsonNull |
//             _RelSingularQuery | _AbsSingularQuery

type _LiteralValue is (String | I64 | F64 | Bool | JsonNull)

type _Comparable is (_LiteralValue | _SingularQuery)

// --- Filter queries (used in existence tests, can be non-singular) ---

class val _RelFilterQuery
  """General query relative to the current node (@)."""
  let segments: Array[_Segment] val

  new val create(segments': Array[_Segment] val) =>
    segments = segments'

class val _AbsFilterQuery
  """General query relative to the document root ($)."""
  let segments: Array[_Segment] val

  new val create(segments': Array[_Segment] val) =>
    segments = segments'

type _FilterQuery is (_RelFilterQuery | _AbsFilterQuery)

// --- Logical expression AST ---

class val _OrExpr
  """Logical OR: true if either operand is true."""
  let left: _LogicalExpr
  let right: _LogicalExpr

  new val create(left': _LogicalExpr, right': _LogicalExpr) =>
    left = left'
    right = right'

class val _AndExpr
  """Logical AND: true if both operands are true."""
  let left: _LogicalExpr
  let right: _LogicalExpr

  new val create(left': _LogicalExpr, right': _LogicalExpr) =>
    left = left'
    right = right'

class val _NotExpr
  """Logical NOT: inverts the operand."""
  let expr: _LogicalExpr

  new val create(expr': _LogicalExpr) =>
    expr = expr'

class val _ComparisonExpr
  """
  Comparison between two comparables.

  Both sides are either literal values or singular queries (which produce
  at most one node). Non-singular queries are not allowed in comparisons
  per RFC 9535 — that constraint is enforced at the type level by using
  `_Comparable` rather than `_FilterQuery`.
  """
  let left: _Comparable
  let op: _ComparisonOp
  let right: _Comparable

  new val create(
    left': _Comparable,
    op': _ComparisonOp,
    right': _Comparable)
  =>
    left = left'
    op = op'
    right = right'

class val _ExistenceExpr
  """
  Existence test: true if the filter query selects at least one node.

  Unlike comparisons, existence tests can use non-singular queries
  (wildcards, slices, descendants).
  """
  let query: _FilterQuery

  new val create(query': _FilterQuery) =>
    query = query'

type _LogicalExpr is
  ( _OrExpr
  | _AndExpr
  | _NotExpr
  | _ComparisonExpr
  | _ExistenceExpr
  )
