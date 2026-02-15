primitive _FilterEval
  """
  Evaluate a filter expression against a current node and document root.

  Returns `true` if the expression matches, `false` otherwise. Evaluation
  never raises — type mismatches, missing keys, and out-of-bounds indices
  all produce well-defined results per RFC 9535.
  """

  fun apply(
    expr: _LogicalExpr,
    current: JsonType,
    root: JsonType)
    : Bool
  =>
    match expr
    | let e: _OrExpr =>
      apply(e.left, current, root) or apply(e.right, current, root)
    | let e: _AndExpr =>
      apply(e.left, current, root) and apply(e.right, current, root)
    | let e: _NotExpr =>
      not apply(e.expr, current, root)
    | let e: _ComparisonExpr =>
      _FilterCompare(e.left, e.op, e.right, current, root)
    | let e: _ExistenceExpr =>
      _eval_existence(e.query, current, root)
    end

  fun _eval_existence(
    query: _FilterQuery,
    current: JsonType,
    root: JsonType)
    : Bool
  =>
    """True if the query selects at least one node."""
    let results = match query
    | let q: _RelFilterQuery =>
      _JsonPathEval(current, root, q.segments)
    | let q: _AbsFilterQuery =>
      _JsonPathEval(root, root, q.segments)
    end
    results.size() > 0

  fun _eval_singular(
    query: _SingularQuery,
    current: JsonType,
    root: JsonType)
    : _QueryResult
  =>
    """
    Evaluate a singular query, returning the single value or `_Nothing`
    if no value exists at that path.
    """
    var node: _QueryResult = match query
    | let q: _RelSingularQuery => current
    | let q: _AbsSingularQuery => root
    end
    let segs = match query
    | let q: _RelSingularQuery => q.segments
    | let q: _AbsSingularQuery => q.segments
    end
    for seg in segs.values() do
      match node
      | let j: JsonType =>
        node = match seg
        | let ns: _SingularNameSegment =>
          match j
          | let obj: JsonObject =>
            try obj(ns.name)? else _Nothing end
          else
            _Nothing
          end
        | let is': _SingularIndexSegment =>
          match j
          | let arr: JsonArray =>
            let idx = is'.index
            let effective = if idx >= 0 then
              idx.usize()
            else
              let abs_idx = idx.abs().usize()
              if abs_idx <= arr.size() then
                arr.size() - abs_idx
              else
                return _Nothing
              end
            end
            try arr(effective)? else _Nothing end
          else
            _Nothing
          end
        end
      | _Nothing => return _Nothing
      end
    end
    node


primitive _FilterCompare
  """
  RFC 9535 comparison semantics for filter expressions.

  Handles Nothing (absent query result), type-specific equality and
  ordering, deep equality for arrays/objects, mixed I64/F64 comparison,
  and cross-type comparisons (always false, no coercion).
  """

  fun apply(
    left: _Comparable,
    op: _ComparisonOp,
    right: _Comparable,
    current: JsonType,
    root: JsonType)
    : Bool
  =>
    let lval = _resolve(left, current, root)
    let rval = _resolve(right, current, root)
    match op
    | _CmpEq  => _eq(lval, rval)
    | _CmpNeq => not _eq(lval, rval)
    | _CmpLt  => _lt(lval, rval)
    | _CmpLte => _lt(lval, rval) or _eq(lval, rval)
    | _CmpGt  => _lt(rval, lval)
    | _CmpGte => _lt(rval, lval) or _eq(lval, rval)
    end

  fun _resolve(
    c: _Comparable,
    current: JsonType,
    root: JsonType)
    : _QueryResult
  =>
    """Resolve a comparable to a concrete value or Nothing."""
    match c
    | let s: String => s
    | let n: I64 => n
    | let n: F64 => n
    | let b: Bool => b
    | JsonNull => JsonNull
    | let q: _RelSingularQuery =>
      _FilterEval._eval_singular(q, current, root)
    | let q: _AbsSingularQuery =>
      _FilterEval._eval_singular(q, current, root)
    end

  fun _eq(left: _QueryResult, right: _QueryResult): Bool =>
    """
    RFC 9535 equality.

    Nothing == Nothing is true. Nothing vs any value is false.
    Same-type primitives use value equality. Mixed I64/F64 converts
    I64 to F64. Arrays compare element-wise recursively. Objects
    compare by same key set with recursively equal values (iteration
    order doesn't matter). Cross-type is false.
    """
    match (left, right)
    | (_Nothing, _Nothing) => true
    | (_Nothing, _) => false
    | (_, _Nothing) => false
    | (let a: I64, let b: I64) => a == b
    | (let a: F64, let b: F64) => a == b
    | (let a: I64, let b: F64) => a.f64() == b
    | (let a: F64, let b: I64) => a == b.f64()
    | (let a: String, let b: String) => a == b
    | (let a: Bool, let b: Bool) => a == b
    | (JsonNull, JsonNull) => true
    | (let a: JsonArray, let b: JsonArray) => _array_eq(a, b)
    | (let a: JsonObject, let b: JsonObject) => _object_eq(a, b)
    else
      false
    end

  fun _lt(left: _QueryResult, right: _QueryResult): Bool =>
    """
    RFC 9535 ordering.

    Anything involving Nothing is false. Numbers (including mixed
    I64/F64) use mathematical ordering. Strings use Unicode scalar
    value lexicographic ordering. All other types and cross-type
    comparisons are false.
    """
    match (left, right)
    | (_Nothing, _) => false
    | (_, _Nothing) => false
    | (let a: I64, let b: I64) => a < b
    | (let a: F64, let b: F64) => a < b
    | (let a: I64, let b: F64) => a.f64() < b
    | (let a: F64, let b: I64) => a < b.f64()
    | (let a: String, let b: String) => a < b
    else
      false
    end

  fun _array_eq(a: JsonArray, b: JsonArray): Bool =>
    """Element-wise recursive equality for arrays."""
    if a.size() != b.size() then return false end
    var i: USize = 0
    while i < a.size() do
      try
        if not _deep_eq(a(i)?, b(i)?) then return false end
      else
        return false
      end
      i = i + 1
    end
    true

  fun _object_eq(a: JsonObject, b: JsonObject): Bool =>
    """
    Key/value recursive equality for objects.

    Checks that both objects have the same number of keys, then verifies
    every key in `a` exists in `b` with a recursively equal value.
    Iteration order doesn't matter (JsonObject is backed by CHAMP map).
    """
    if a.size() != b.size() then return false end
    for (key, a_val) in a.pairs() do
      try
        let b_val = b(key)?
        if not _deep_eq(a_val, b_val) then return false end
      else
        return false
      end
    end
    true

  fun _deep_eq(a: JsonType, b: JsonType): Bool =>
    """Recursive equality for JsonType values."""
    match (a, b)
    | (let x: I64, let y: I64) => x == y
    | (let x: F64, let y: F64) => x == y
    | (let x: I64, let y: F64) => x.f64() == y
    | (let x: F64, let y: I64) => x == y.f64()
    | (let x: String, let y: String) => x == y
    | (let x: Bool, let y: Bool) => x == y
    | (JsonNull, JsonNull) => true
    | (let x: JsonArray, let y: JsonArray) => _array_eq(x, y)
    | (let x: JsonObject, let y: JsonObject) => _object_eq(x, y)
    else
      false
    end
