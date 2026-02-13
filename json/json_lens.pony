class val JsonLens
  """
  Composable, reusable JSON path for reading and modifying nested values.

  Define a lens by chaining key/index steps, then apply it to any document:

  ```pony
  let host_lens = JsonLens("config")("database")("host")

  // Read
  match host_lens.get(doc)
  | let host: String => env.out.print(host)
  | NotFound => env.out.print("no host configured")
  end

  // Modify (returns new document with the change applied)
  match host_lens.set(doc, "newhost.example.com")
  | let updated: JsonType => // updated doc
  | NotFound => // path didn't exist
  end
  ```
  """

  let _traversal: _JsonTraversal

  new val create() =>
    """Create an identity lens (focuses on the root value)."""
    _traversal = _NoTraversal

  new val _trav(trav': _JsonTraversal) =>
    _traversal = trav'

  fun apply(key_or_index: (String | USize)): JsonLens =>
    """Compose a navigation step onto this lens."""
    let step: _JsonTraversal = match key_or_index
    | let k: String => _TravObjKey(k)
    | let i: USize => _TravArrayIndex(i)
    end
    JsonLens._trav(_traversal.compose(step))

  fun get(input: JsonType): (JsonType | NotFound) =>
    """Apply this lens to read a value."""
    _traversal(input)

  fun set(input: JsonType, value: JsonType): (JsonType | NotFound) =>
    """
    Apply this lens to update a value, returning a new root.
    Returns NotFound if the path doesn't exist.
    """
    _traversal.update(input, value)

  fun remove(input: JsonType): (JsonType | NotFound) =>
    """
    Apply this lens to remove a value, returning a new root.
    Returns NotFound if the path doesn't exist.
    """
    _traversal.update(input, None)

  fun compose(other: JsonLens): JsonLens =>
    """Sequential composition: navigate this lens, then the other."""
    JsonLens._trav(_traversal.compose(other._traversal))

  fun or_else(alt: JsonLens): JsonLens =>
    """Choice: try this lens, fall back to alt if NotFound."""
    JsonLens._trav(_traversal.or_else(alt._traversal))
