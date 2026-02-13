type _Selector is
  ( _NameSelector
  | _IndexSelector
  | _WildcardSelector
  | _SliceSelector
  )

class val _NameSelector
  """Select an object member by key name."""
  let _name: String

  new val create(name': String) =>
    _name = name'

  fun select(node: JsonType, out: Array[JsonType] ref) =>
    match node
    | let obj: JsonObject =>
      try out.push(obj(_name)?) end
    end

class val _IndexSelector
  """Select an array element by index. Supports negative indices."""
  let _index: I64

  new val create(index': I64) =>
    _index = index'

  fun select(node: JsonType, out: Array[JsonType] ref) =>
    match node
    | let arr: JsonArray =>
      let effective = if _index >= 0 then
        _index.usize()
      else
        let abs_idx = _index.abs().usize()
        if abs_idx <= arr.size() then
          arr.size() - abs_idx
        else
          return
        end
      end
      try out.push(arr(effective)?) end
    end

primitive _WildcardSelector
  """Select all children of an object or array."""

  fun select(node: JsonType, out: Array[JsonType] ref) =>
    match node
    | let obj: JsonObject =>
      for v in obj.values() do out.push(v) end
    | let arr: JsonArray =>
      for v in arr.values() do out.push(v) end
    end

class val _SliceSelector
  """
  Select a range of array elements.

  Implements RFC 9535 slice semantics: [start:end] where start is
  inclusive and end is exclusive. Missing start defaults to 0, missing
  end defaults to array length. Negative values wrap from the end.
  """
  let _start: (I64 | None)
  let _end: (I64 | None)

  new val create(start': (I64 | None), end': (I64 | None)) =>
    _start = start'
    _end = end'

  fun select(node: JsonType, out: Array[JsonType] ref) =>
    match node
    | let arr: JsonArray =>
      let len = arr.size().i64()
      let s = _normalize(
        match _start | let n: I64 => n else I64(0) end, len)
      let e = _normalize(
        match _end | let n: I64 => n else len end, len)
      let lower = s.max(0).min(len)
      let upper = e.max(0).min(len)
      var i = lower
      while i < upper do
        try out.push(arr(i.usize())?) end
        i = i + 1
      end
    end

  fun _normalize(idx: I64, len: I64): I64 =>
    if idx >= 0 then idx else len + idx end
