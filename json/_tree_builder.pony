use pc = "collections/persistent"

class ref _ObjectInProgress
  var map: pc.Map[String, JsonType]
  var pending_key: (String | None)

  new ref create() =>
    map = pc.Map[String, JsonType]
    pending_key = None

class ref _ArrayInProgress
  var vec: pc.Vec[JsonType]

  new ref create() =>
    vec = pc.Vec[JsonType]

class ref _TreeBuilder is JsonTokenNotify
  """
  Internal token consumer that assembles a JsonType tree from token events.
  Used by JsonParser to build the full parse result.
  """

  var _stack: Array[(_ObjectInProgress | _ArrayInProgress)]
  var _result: (JsonType | None)

  new ref create() =>
    _stack = Array[(_ObjectInProgress | _ArrayInProgress)]
    _result = None

  fun ref apply(parser: JsonTokenParser, token: JsonToken) =>
    match token
    | JsonTokenObjectStart =>
      _stack.push(_ObjectInProgress)
    | JsonTokenArrayStart =>
      _stack.push(_ArrayInProgress)
    | JsonTokenKey =>
      try
        match _stack(_stack.size() - 1)?
        | let obj: _ObjectInProgress =>
          obj.pending_key = parser.last_string
        end
      end
    | JsonTokenString =>
      _add_value(parser.last_string)
    | JsonTokenNumber =>
      match parser.last_number
      | let n: I64 => _add_value(n)
      | let n: F64 => _add_value(n)
      end
    | JsonTokenTrue =>
      _add_value(true)
    | JsonTokenFalse =>
      _add_value(false)
    | JsonTokenNull =>
      _add_value(JsonNull)
    | JsonTokenObjectEnd =>
      try
        let obj = _stack.pop()? as _ObjectInProgress
        _add_value(JsonObject(obj.map))
      end
    | JsonTokenArrayEnd =>
      try
        let arr = _stack.pop()? as _ArrayInProgress
        _add_value(JsonArray(arr.vec))
      end
    end

  fun ref _add_value(value: JsonType) =>
    if _stack.size() == 0 then
      _result = value
    else
      try
        match _stack(_stack.size() - 1)?
        | let obj: _ObjectInProgress =>
          match obj.pending_key
          | let key: String =>
            obj.map = obj.map(key) = value
            obj.pending_key = None
          end
        | let arr: _ArrayInProgress =>
          arr.vec = arr.vec.push(value)
        end
      end
    end

  fun result(): (JsonType | None) =>
    _result
