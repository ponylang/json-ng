trait val _JsonTraversal
  """
  Internal trait for lens traversal operations.

  apply: read a value at the focus point.
  update: write or delete a value at the focus point, returning a new root.
  """
  fun apply(v: JsonType): (JsonType | NotFound)
  fun update(input: JsonType, value: (JsonType | None)): (JsonType | NotFound)
  fun val compose(t: _JsonTraversal): _JsonTraversal => _TravCompose(this, t)
  fun val or_else(alt: _JsonTraversal): _JsonTraversal => _TravChoice(this, alt)

primitive _NoTraversal is _JsonTraversal
  """Identity traversal — returns the input unchanged."""
  fun apply(v: JsonType): (JsonType | NotFound) => v
  fun update(input: JsonType, value: (JsonType | None)): (JsonType | NotFound) =>
    match value
    | let j: JsonType => j
    else NotFound
    end

class val _TravObjKey is _JsonTraversal
  """Focus on an object key."""
  let _key: String

  new val create(key: String) => _key = key

  fun apply(v: JsonType): (JsonType | NotFound) =>
    try (v as JsonObject)(_key)?
    else NotFound
    end

  fun update(input: JsonType, value: (JsonType | None)): (JsonType | NotFound) =>
    try
      let obj = input as JsonObject
      match value
      | let j: JsonType => obj.update(_key, j)
      | None => obj.remove(_key)
      end
    else
      NotFound
    end

class val _TravArrayIndex is _JsonTraversal
  """Focus on an array index."""
  let _idx: USize

  new val create(idx: USize) => _idx = idx

  fun apply(v: JsonType): (JsonType | NotFound) =>
    try (v as JsonArray)(_idx)?
    else NotFound
    end

  fun update(input: JsonType, value: (JsonType | None)): (JsonType | NotFound) =>
    try
      let arr = input as JsonArray
      match value
      | let j: JsonType => arr.update(_idx, j)?
      else
        // None (remove) on array index — not supported, return NotFound
        NotFound
      end
    else
      NotFound
    end

class val _TravCompose is _JsonTraversal
  """Sequential composition: navigate _a, then navigate _b within the result."""
  let _a: _JsonTraversal
  let _b: _JsonTraversal

  new val create(a: _JsonTraversal, b: _JsonTraversal) =>
    _a = a
    _b = b

  fun apply(v: JsonType): (JsonType | NotFound) =>
    match _a(v)
    | let j: JsonType => _b(j)
    else NotFound
    end

  fun update(input: JsonType, value: (JsonType | None)): (JsonType | NotFound) =>
    try
      let intermediate = _a(input) as JsonType
      let inner_result = _b.update(intermediate, value) as JsonType
      _a.update(input, inner_result)
    else
      NotFound
    end

class val _TravChoice is _JsonTraversal
  """Choice: try _a, fall back to _b if NotFound."""
  let _a: _JsonTraversal
  let _b: _JsonTraversal

  new val create(a: _JsonTraversal, b: _JsonTraversal) =>
    _a = a
    _b = b

  fun apply(v: JsonType): (JsonType | NotFound) =>
    match _a(v)
    | let j: JsonType => j
    else _b(v)
    end

  fun update(input: JsonType, value: (JsonType | None)): (JsonType | NotFound) =>
    match _a(input)
    | let _: JsonType => _a.update(input, value)
    else _b.update(input, value)
    end
