primitive _JsonPathEval
  """
  Internal evaluator for compiled JSONPath queries.

  Applies a sequence of segments to a root JSON value, producing an
  array of matching values. Evaluation never raises — missing keys,
  wrong types, and out-of-bounds indices all produce empty results
  (per RFC 9535).
  """

  fun apply(
    root: JsonType,
    segments: Array[_Segment] val)
    : Array[JsonType] val
  =>
    """Execute segments against root, returning matching values."""
    recover val
      var current: Array[JsonType] ref = Array[JsonType]
      current.push(root)

      for segment in segments.values() do
        current = _apply_segment(segment, current)
      end

      current
    end

  fun _apply_segment(
    segment: _Segment,
    input: Array[JsonType] ref)
    : Array[JsonType] ref
  =>
    """Apply a segment to produce a new nodelist."""
    match segment
    | let cs: _ChildSegment => _apply_child(cs.selectors(), input)
    | let ds: _DescendantSegment => _apply_descendant(ds.selectors(), input)
    end

  fun _apply_child(
    selectors: Array[_Selector] val,
    input: Array[JsonType] ref)
    : Array[JsonType] ref
  =>
    """Apply selectors to each node in the input list."""
    let out = Array[JsonType]
    for node in input.values() do
      _select_all(selectors, node, out)
    end
    out

  fun _apply_descendant(
    selectors: Array[_Selector] val,
    input: Array[JsonType] ref)
    : Array[JsonType] ref
  =>
    """
    For each input node, walk the entire subtree depth-first and
    apply selectors at every level.
    """
    let out = Array[JsonType]
    for node in input.values() do
      _descend(selectors, node, out)
    end
    out

  fun _descend(
    selectors: Array[_Selector] val,
    node: JsonType,
    out: Array[JsonType] ref)
  =>
    """Depth-first pre-order: apply selectors here, then recurse."""
    _select_all(selectors, node, out)
    match node
    | let obj: JsonObject =>
      for v in obj.values() do _descend(selectors, v, out) end
    | let arr: JsonArray =>
      for v in arr.values() do _descend(selectors, v, out) end
    end

  fun _select_all(
    selectors: Array[_Selector] val,
    node: JsonType,
    out: Array[JsonType] ref)
  =>
    """Apply all selectors to a single node."""
    for selector in selectors.values() do
      match selector
      | let s: _NameSelector => s.select(node, out)
      | let s: _IndexSelector => s.select(node, out)
      | _WildcardSelector => _WildcardSelector.select(node, out)
      | let s: _SliceSelector => s.select(node, out)
      end
    end
