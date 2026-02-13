class ref _JsonPathParser
  """
  Internal recursive descent parser for JSONPath expressions.

  Raises on invalid input. The public JsonPathParser.parse() wraps
  this and catches errors, consistent with how JsonParser wraps
  JsonTokenParser.
  """
  let _source: String
  var _offset: USize = 0
  var _error_message: String = ""

  new ref create(source': String) =>
    _source = source'

  fun ref parse(): Array[_Segment] val ? =>
    """Parse a complete JSONPath expression. Raises on invalid input."""
    _eat('$')?
    let segments = recover iso Array[_Segment] end
    while _offset < _source.size() do
      segments.push(_parse_segment()?)
    end
    consume segments

  fun error_result(): JsonPathParseError =>
    """Return a parse error with current position context."""
    JsonPathParseError(_error_message, _offset)

  // --- Segment parsing ---

  fun ref _parse_segment(): _Segment ? =>
    """Parse a child or descendant segment."""
    if _looking_at_str("..") then
      _advance(2)
      _parse_descendant_segment()?
    elseif _looking_at('.') then
      _advance(1)
      _parse_dot_child()?
    elseif _looking_at('[') then
      _parse_bracket_child()?
    else
      _fail("Expected '.', '..', or '['")
      error
    end

  fun ref _parse_descendant_segment(): _Segment ? =>
    """Parse after '..' — either bracket selectors or dot member/wildcard."""
    let selectors = if _looking_at('[') then
      _parse_bracket_selectors()?
    elseif _looking_at('*') then
      _advance(1)
      recover val [as _Selector: _WildcardSelector] end
    else
      let name = _parse_member_name()?
      recover val [as _Selector: _NameSelector(name)] end
    end
    _DescendantSegment(selectors)

  fun ref _parse_dot_child(): _Segment ? =>
    """Parse after '.' — either wildcard or member name."""
    let selectors = if _looking_at('*') then
      _advance(1)
      recover val [as _Selector: _WildcardSelector] end
    else
      let name = _parse_member_name()?
      recover val [as _Selector: _NameSelector(name)] end
    end
    _ChildSegment(selectors)

  fun ref _parse_bracket_child(): _Segment ? =>
    """Parse bracket notation '[selectors]' as a child segment."""
    let selectors = _parse_bracket_selectors()?
    _ChildSegment(selectors)

  // --- Bracket selector parsing ---

  fun ref _parse_bracket_selectors(): Array[_Selector] val ? =>
    """Parse '[' selector (',' selector)* ']'."""
    _eat('[')?
    _skip_whitespace()
    let selectors = recover iso Array[_Selector] end
    selectors.push(_parse_selector()?)
    while true do
      _skip_whitespace()
      if _looking_at(']') then
        _advance(1)
        break
      elseif _looking_at(',') then
        _advance(1)
        _skip_whitespace()
        selectors.push(_parse_selector()?)
      else
        _fail("Expected ',' or ']' in bracket selector")
        error
      end
    end
    consume selectors

  fun ref _parse_selector(): _Selector ? =>
    """
    Parse a single selector inside brackets.
    Distinguishes: string name, wildcard, index, or slice.
    """
    _skip_whitespace()
    if _looking_at('*') then
      _advance(1)
      _WildcardSelector
    elseif _looking_at('\'') or _looking_at('"') then
      let name = _parse_quoted_string()?
      _NameSelector(name)
    else
      _parse_index_or_slice()?
    end

  fun ref _parse_index_or_slice(): _Selector ? =>
    """
    Parse an integer index or a slice expression.

    Disambiguation: if we see ':' after the optional first integer,
    it's a slice; otherwise it's an index.
    """
    let first: (I64 | None) = _try_parse_int()

    _skip_whitespace()
    if _looking_at(':') then
      _advance(1)
      _skip_whitespace()
      let end_val: (I64 | None) = _try_parse_int()
      _SliceSelector(first, end_val)
    else
      match first
      | let n: I64 => _IndexSelector(n)
      else
        _fail("Expected integer index, string name, or ':' for slice")
        error
      end
    end

  // --- Leaf parsing ---

  fun ref _parse_member_name(): String ? =>
    """Parse an unquoted member name (dot notation)."""
    let start = _offset
    if _offset >= _source.size() then
      _fail("Expected member name")
      error
    end
    let first = _source(_offset)?
    if not (_is_alpha(first) or (first == '_')) then
      _fail("Expected letter or '_' at start of member name")
      error
    end
    _advance(1)
    while _offset < _source.size() do
      let c = _source(_offset)?
      if _is_alpha(c) or _is_digit(c) or (c == '_') then
        _advance(1)
      else
        break
      end
    end
    _source.substring(start.isize(), _offset.isize())

  fun ref _parse_quoted_string(): String ? =>
    """Parse a single- or double-quoted string with escape handling."""
    let quote = _next()?
    let buf = String
    while true do
      if _offset >= _source.size() then
        _fail("Unterminated string")
        error
      end
      let c = _next()?
      if c == quote then
        break
      elseif c == '\\' then
        if _offset >= _source.size() then
          _fail("Unterminated escape sequence")
          error
        end
        let esc = _next()?
        match esc
        | '"' => buf.push('"')
        | '\'' => buf.push('\'')
        | '\\' => buf.push('\\')
        | '/' => buf.push('/')
        | 'b' => buf.push(0x08)
        | 'f' => buf.push(0x0C)
        | 'n' => buf.push('\n')
        | 'r' => buf.push('\r')
        | 't' => buf.push('\t')
        | 'u' => _parse_unicode_escape(buf)?
        else
          _fail("Invalid escape sequence")
          error
        end
      else
        buf.push(c)
      end
    end
    buf.clone()

  fun ref _parse_unicode_escape(buf: String ref) ? =>
    """Parse \\uXXXX and surrogate pairs, appending to buf."""
    let value = _read_hex4()?
    if (value >= 0xD800) and (value < 0xDC00) then
      // High surrogate — expect \uXXXX low surrogate
      _eat('\\')?
      _eat('u')?
      let low = _read_hex4()?
      if (low >= 0xDC00) and (low < 0xE000) then
        let combined =
          0x10000 + (((value and 0x3FF) << 10) or (low and 0x3FF))
        buf.append(recover val String.from_utf32(combined) end)
      else
        _fail("Invalid surrogate pair")
        error
      end
    elseif (value >= 0xDC00) and (value < 0xE000) then
      _fail("Lone low surrogate")
      error
    else
      buf.append(recover val String.from_utf32(value) end)
    end

  fun ref _read_hex4(): U32 ? =>
    """Read exactly 4 hex digits and return the value."""
    var result: U32 = 0
    var i: USize = 0
    while i < 4 do
      let c = _next()?
      let digit: U32 = if (c >= '0') and (c <= '9') then
        (c - '0').u32()
      elseif (c >= 'a') and (c <= 'f') then
        (c - 'a').u32() + 10
      elseif (c >= 'A') and (c <= 'F') then
        (c - 'A').u32() + 10
      else
        _fail("Invalid hex digit")
        error
      end
      result = (result << 4) or digit
      i = i + 1
    end
    result

  fun ref _try_parse_int(): (I64 | None) =>
    """Try to parse an integer. Returns None if not at a digit or '-'."""
    if _offset >= _source.size() then return None end
    try
      let c = _source(_offset)?
      if _is_digit(c) or (c == '-') then
        _parse_int()?
      else
        None
      end
    else
      None
    end

  fun ref _parse_int(): I64 ? =>
    """Parse a (possibly negative) integer."""
    var negative = false
    if _looking_at('-') then
      negative = true
      _advance(1)
    end
    let start = _offset
    while (_offset < _source.size()) and
      try _is_digit(_source(_offset)?) else false end
    do
      _advance(1)
    end
    if _offset == start then
      _fail("Expected digit")
      error
    end
    let num_str: String val =
      _source.substring(start.isize(), _offset.isize())
    let abs_val = num_str.i64()?
    if negative then -abs_val else abs_val end

  // --- Character primitives ---

  fun _looking_at(c: U8): Bool =>
    try _source(_offset)? == c else false end

  fun _looking_at_str(s: String): Bool =>
    if (_offset + s.size()) > _source.size() then return false end
    try
      var i: USize = 0
      while i < s.size() do
        if _source(_offset + i)? != s(i)? then return false end
        i = i + 1
      end
      true
    else
      false
    end

  fun ref _advance(n: USize) =>
    _offset = _offset + n

  fun ref _next(): U8 ? =>
    if _offset >= _source.size() then
      _fail("Unexpected end of path")
      error
    end
    let c = _source(_offset)?
    _offset = _offset + 1
    c

  fun ref _eat(expected: U8) ? =>
    if _offset >= _source.size() then
      _fail("Expected '" + String.from_array([expected]) +
        "' but reached end of path")
      error
    end
    if _source(_offset)? != expected then
      _fail("Expected '" + String.from_array([expected]) + "'")
      error
    end
    _offset = _offset + 1

  fun ref _skip_whitespace() =>
    while (_offset < _source.size()) and
      try
        let c = _source(_offset)?
        (c == ' ') or (c == '\t') or (c == '\n') or (c == '\r')
      else
        false
      end
    do
      _offset = _offset + 1
    end

  fun ref _fail(msg: String) =>
    _error_message = msg

  fun _is_alpha(c: U8): Bool =>
    ((c >= 'a') and (c <= 'z')) or ((c >= 'A') and (c <= 'Z'))

  fun _is_digit(c: U8): Bool =>
    (c >= '0') and (c <= '9')
