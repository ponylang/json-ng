primitive _JsonPathEval
  """
  Internal evaluator for compiled JSONPath queries.

  Applies a sequence of segments to a starting JSON value, producing an
  array of matching values. Evaluation never raises — missing keys,
  wrong types, and out-of-bounds indices all produce empty results
  (per RFC 9535).

  The `start` and `root` parameters are distinct: `start` is the node
  the query begins from, while `root` is the original document root for
  resolving absolute queries (`$`) inside filter expressions. For
  top-level queries, both are the document root.
  """

  fun apply(
    start: JsonType,
    root: JsonType,
    segments: Array[_Segment] val)
    : Array[JsonType] val
  =>
    """Execute segments against start, returning matching values."""
    recover val
      var current: Array[JsonType] ref = Array[JsonType]
      current.push(start)

      for segment in segments.values() do
        current = _apply_segment(segment, current, root)
      end

      current
    end

  fun _apply_segment(
    segment: _Segment,
    input: Array[JsonType] ref,
    root: JsonType)
    : Array[JsonType] ref
  =>
    """Apply a segment to produce a new nodelist."""
    match segment
    | let cs: _ChildSegment =>
      _apply_child(cs.selectors(), input, root)
    | let ds: _DescendantSegment =>
      _apply_descendant(ds.selectors(), input, root)
    end

  fun _apply_child(
    selectors: Array[_Selector] val,
    input: Array[JsonType] ref,
    root: JsonType)
    : Array[JsonType] ref
  =>
    """Apply selectors to each node in the input list."""
    let out = Array[JsonType]
    for node in input.values() do
      _select_all(selectors, node, root, out)
    end
    out

  fun _apply_descendant(
    selectors: Array[_Selector] val,
    input: Array[JsonType] ref,
    root: JsonType)
    : Array[JsonType] ref
  =>
    """
    For each input node, walk the entire subtree depth-first and
    apply selectors at every level.
    """
    let out = Array[JsonType]
    for node in input.values() do
      _descend(selectors, node, root, out)
    end
    out

  fun _descend(
    selectors: Array[_Selector] val,
    node: JsonType,
    root: JsonType,
    out: Array[JsonType] ref)
  =>
    """Depth-first pre-order: apply selectors here, then recurse."""
    _select_all(selectors, node, root, out)
    match node
    | let obj: JsonObject =>
      for v in obj.values() do _descend(selectors, v, root, out) end
    | let arr: JsonArray =>
      for v in arr.values() do _descend(selectors, v, root, out) end
    end

  // _FilterSelector.select takes an extra `root` parameter. This is
  // handled here via explicit match dispatch — changing the _FilterSelector
  // match arm without affecting other selectors' signatures.
  fun _select_all(
    selectors: Array[_Selector] val,
    node: JsonType,
    root: JsonType,
    out: Array[JsonType] ref)
  =>
    """Apply all selectors to a single node."""
    for selector in selectors.values() do
      match selector
      | let s: _NameSelector => s.select(node, out)
      | let s: _IndexSelector => s.select(node, out)
      | _WildcardSelector => _WildcardSelector.select(node, out)
      | let s: _SliceSelector => s.select(node, out)
      | let s: _FilterSelector => s.select(node, root, out)
      end
    end
