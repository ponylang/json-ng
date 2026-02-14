use "pony_test"
use "pony_check"

actor \nodoc\ Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  fun tag tests(test: PonyTest) =>
    // Property tests
    test(Property1UnitTest[I64](_ArrayPushApplyProperty))
    test(Property1UnitTest[I64](_ArrayPushPopProperty))
    test(Property1UnitTest[USize](_ArraySizeProperty))
    test(Property1UnitTest[F64](_F64RoundtripProperty))
    test(Property1UnitTest[I64](_I64RoundtripProperty))
    test(Property1UnitTest[String](_JsonPathSafetyProperty))
    test(Property1UnitTest[String](_ObjectRemoveProperty))
    test(Property1UnitTest[(String, String)](_ObjectSizeProperty))
    test(Property1UnitTest[(String, I64)](_ObjectUpdateApplyProperty))
    test(Property1UnitTest[String](_ParsePrintRoundtripProperty))
    test(Property1UnitTest[String](_StringEscapeRoundtripProperty))
    // Example tests
    test(_TestArrayUpdate)
    test(_TestJsonPathParse)
    test(_TestJsonPathParseErrors)
    test(_TestJsonPathQueryAdvanced)
    test(_TestJsonPathQueryBasic)
    test(_TestJsonPathQueryComplex)
    test(_TestJsonPathQuerySliceStep)
    test(_TestLensComposition)
    test(_TestLensGet)
    test(_TestLensRemove)
    test(_TestLensSet)
    test(_TestNavInspection)
    test(_TestNavNotFound)
    test(_TestNavSuccess)
    test(_TestObjectGetOrElse)
    test(_TestParseContainers)
    test(_TestParseErrorLoneSurrogates)
    test(_TestParseErrors)
    test(_TestParseKeywords)
    test(_TestParseNumbers)
    test(_TestParseStrings)
    test(_TestParseWholeDocument)
    test(_TestPrintCompact)
    test(_TestPrintFloats)
    test(_TestPrintPretty)
    test(_TestTokenParserAbort)

// ===================================================================
// Generators
// ===================================================================

primitive \nodoc\ _JsonValueStringGen
  """
  Generates valid JSON text strings with depth-bounded recursion.
  Produces strings like "42", "\"hello\"", "[1,true]", "{\"a\":1}".
  """
  fun apply(max_depth: USize = 2): Generator[String] =>
    let that = this
    Generator[String](
      object is GenObj[String]
        fun generate(rnd: Randomness): String =>
          that._gen_value(rnd, max_depth)
      end)

  fun _gen_value(rnd: Randomness, depth: USize): String =>
    let choice = if depth == 0 then
      rnd.usize(0, 4)
    else
      rnd.usize(0, 6)
    end
    match choice
    | 0 => _gen_int(rnd)
    | 1 => _gen_float(rnd)
    | 2 => if rnd.bool() then "true" else "false" end
    | 3 => "null"
    | 4 => _gen_string(rnd)
    | 5 => _gen_object(rnd, depth - 1)
    | 6 => _gen_array(rnd, depth - 1)
    else "null"
    end

  fun _gen_int(rnd: Randomness): String =>
    rnd.i64(-1000, 1000).string()

  fun _gen_float(rnd: Randomness): String =>
    let numerator = rnd.i64(-100, 100)
    let denom: I64 = match rnd.usize(0, 3)
    | 0 => 2
    | 1 => 4
    | 2 => 5
    else 10
    end
    let f = numerator.f64() / denom.f64()
    let s: String val = f.string()
    if
      (not s.contains("."))
        and (not s.contains("e"))
        and (not s.contains("E"))
    then
      s + ".0"
    else
      s
    end

  fun _gen_string(rnd: Randomness): String =>
    let len = rnd.usize(0, 15)
    var buf: String ref = String(len + 2)
    buf.push('"')
    var i: USize = 0
    while i < len do
      let c = rnd.u8(0x20, 0x7E)
      if c == '"' then
        buf.append("\\\"")
      elseif c == '\\' then
        buf.append("\\\\")
      else
        buf.push(c)
      end
      i = i + 1
    end
    buf.push('"')
    buf.clone()

  fun _gen_object(rnd: Randomness, depth: USize): String =>
    let count = rnd.usize(0, 3)
    if count == 0 then return "{}" end
    var buf: String ref = String(64)
    buf.push('{')
    var i: USize = 0
    while i < count do
      if i > 0 then buf.push(',') end
      // generate a simple key
      let key_len = rnd.usize(1, 6)
      buf.push('"')
      var k: USize = 0
      while k < key_len do
        buf.push(rnd.u8('a', 'z'))
        k = k + 1
      end
      buf.push('"')
      buf.push(':')
      buf.append(_gen_value(rnd, depth))
      i = i + 1
    end
    buf.push('}')
    buf.clone()

  fun _gen_array(rnd: Randomness, depth: USize): String =>
    let count = rnd.usize(0, 4)
    if count == 0 then return "[]" end
    var buf: String ref = String(64)
    buf.push('[')
    var i: USize = 0
    while i < count do
      if i > 0 then buf.push(',') end
      buf.append(_gen_value(rnd, depth))
      i = i + 1
    end
    buf.push(']')
    buf.clone()

// ===================================================================
// Property Tests — Roundtrip
// ===================================================================

class \nodoc\ iso _ParsePrintRoundtripProperty is Property1[String]
  fun name(): String => "json/roundtrip/compact"

  fun gen(): Generator[String] =>
    _JsonValueStringGen(2)

  fun ref property(sample: String, ph: PropertyHelper) =>
    // compact(parse(s)) is a fixpoint after one cycle
    let first_parse = JsonParser.parse(sample)
    match first_parse
    | let j1: JsonType =>
      let s1: String val = _JsonPrint.compact(j1)
      match JsonParser.parse(s1)
      | let j2: JsonType =>
        let s2: String val = _JsonPrint.compact(j2)
        ph.assert_eq[String val](s1, s2)
      | let e: JsonParseError =>
        ph.fail("Re-parse failed: " + e.string())
      end
    | let e: JsonParseError =>
      ph.fail("Initial parse failed for: " + sample + " — " + e.string())
    end

class \nodoc\ iso _I64RoundtripProperty is Property1[I64]
  fun name(): String => "json/roundtrip/i64"

  fun gen(): Generator[I64] =>
    // Restrict to 18-digit range: values with 19+ digits are promoted to F64
    // by the parser to avoid silent I64 overflow
    Generators.i64(-999_999_999_999_999_999, 999_999_999_999_999_999)

  fun ref property(sample: I64, ph: PropertyHelper) =>
    let s: String val = sample.string()
    match JsonParser.parse(s)
    | let j: JsonType =>
      try
        let parsed = j as I64
        ph.assert_eq[I64](sample, parsed)
      else
        ph.fail("Parsed as wrong type for: " + s)
      end
    | let e: JsonParseError =>
      ph.fail("Parse failed for: " + s + " — " + e.string())
    end

class \nodoc\ iso _F64RoundtripProperty is Property1[F64]
  fun name(): String => "json/roundtrip/f64"

  fun gen(): Generator[F64] =>
    // Generate clean-roundtripping F64 values
    Generator[F64](
      object is GenObj[F64]
        fun generate(rnd: Randomness): F64 =>
          let n = rnd.i64(-100, 100)
          let d: I64 = match rnd.usize(0, 3)
          | 0 => 2
          | 1 => 4
          | 2 => 5
          else 10
          end
          n.f64() / d.f64()
      end)

  fun ref property(sample: F64, ph: PropertyHelper) =>
    // Serialize as a JSON array element to handle the formatting
    let arr = JsonArray.push(sample)
    let s: String val = _JsonPrint.compact(arr)
    match JsonParser.parse(s)
    | let j: JsonType =>
      try
        let parsed_arr = j as JsonArray
        let parsed = parsed_arr(0)? as F64
        ph.assert_eq[F64](sample, parsed)
      else
        ph.fail("Type mismatch after roundtrip for: " + sample.string())
      end
    | let e: JsonParseError =>
      ph.fail("Parse failed for: " + s + " — " + e.string())
    end

class \nodoc\ iso _StringEscapeRoundtripProperty is Property1[String]
  fun name(): String => "json/roundtrip/string-escape"

  fun gen(): Generator[String] =>
    Generators.ascii(0, 50)

  fun ref property(sample: String, ph: PropertyHelper) =>
    // Embed string in a JSON array, serialize, parse, extract
    let arr = JsonArray.push(sample)
    let serialized: String val = _JsonPrint.compact(arr)
    match JsonParser.parse(serialized)
    | let j: JsonType =>
      try
        let parsed_arr = j as JsonArray
        let recovered = parsed_arr(0)? as String
        ph.assert_eq[String val](sample, recovered)
      else
        ph.fail("Type mismatch in string roundtrip")
      end
    | let e: JsonParseError =>
      ph.fail("Parse failed: " + e.string())
    end

// ===================================================================
// Property Tests — JsonObject
// ===================================================================

class \nodoc\ iso _ObjectUpdateApplyProperty is Property1[(String, I64)]
  fun name(): String => "json/object/update-apply"

  fun gen(): Generator[(String, I64)] =>
    Generators.zip2[String, I64](
      Generators.ascii_letters(1, 10),
      Generators.i64(-1000, 1000))

  fun ref property(sample: (String, I64), ph: PropertyHelper) ? =>
    (let key, let value) = sample
    let obj = JsonObject.update(key, value)
    let got = obj(key)? as I64
    ph.assert_eq[I64](value, got)

class \nodoc\ iso _ObjectRemoveProperty is Property1[String]
  fun name(): String => "json/object/remove"

  fun gen(): Generator[String] =>
    Generators.ascii_letters(1, 10)

  fun ref property(sample: String, ph: PropertyHelper) =>
    let obj = JsonObject.update(sample, I64(42))
    ph.assert_true(obj.contains(sample))
    let removed = obj.remove(sample)
    ph.assert_false(removed.contains(sample))

class \nodoc\ iso _ObjectSizeProperty is Property1[(String, String)]
  fun name(): String => "json/object/size"

  fun gen(): Generator[(String, String)] =>
    Generators.zip2[String, String](
      Generators.ascii_letters(1, 10),
      Generators.ascii_letters(1, 10))

  fun ref property(sample: (String, String), ph: PropertyHelper) =>
    (let k1, let k2) = sample
    // Update with first key — size is 1
    let obj1 = JsonObject.update(k1, I64(1))
    ph.assert_eq[USize](1, obj1.size())

    // Update same key — size stays 1
    let obj2 = obj1.update(k1, I64(2))
    ph.assert_eq[USize](1, obj2.size())

    // Update with different key — size depends on whether keys are equal
    let obj3 = obj1.update(k2, I64(3))
    if k1 == k2 then
      ph.assert_eq[USize](1, obj3.size())
    else
      ph.assert_eq[USize](2, obj3.size())
    end

// ===================================================================
// Property Tests — JsonArray
// ===================================================================

class \nodoc\ iso _ArrayPushApplyProperty is Property1[I64]
  fun name(): String => "json/array/push-apply"

  fun gen(): Generator[I64] =>
    Generators.i64()

  fun ref property(sample: I64, ph: PropertyHelper) ? =>
    let arr = JsonArray.push(sample)
    let got = arr(arr.size() - 1)? as I64
    ph.assert_eq[I64](sample, got)

class \nodoc\ iso _ArrayPushPopProperty is Property1[I64]
  fun name(): String => "json/array/push-pop"

  fun gen(): Generator[I64] =>
    Generators.i64()

  fun ref property(sample: I64, ph: PropertyHelper) ? =>
    let base = JsonArray.push(I64(99))
    let extended = base.push(sample)
    (let popped, let value) = extended.pop()?
    let got = value as I64
    ph.assert_eq[I64](sample, got)
    ph.assert_eq[USize](base.size(), popped.size())

class \nodoc\ iso _ArraySizeProperty is Property1[USize]
  fun name(): String => "json/array/size"

  fun gen(): Generator[USize] =>
    Generators.usize(0, 20)

  fun ref property(sample: USize, ph: PropertyHelper) =>
    var arr = JsonArray
    var i: USize = 0
    while i < sample do
      arr = arr.push(I64(i.i64()))
      i = i + 1
    end
    ph.assert_eq[USize](sample, arr.size())

// ===================================================================
// Property Tests — JSONPath Safety
// ===================================================================

class \nodoc\ iso _JsonPathSafetyProperty is Property1[String]
  fun name(): String => "json/jsonpath/safety"

  fun gen(): Generator[String] =>
    _JsonValueStringGen(2)

  fun ref property(sample: String, ph: PropertyHelper) =>
    // Parse the generated JSON
    match JsonParser.parse(sample)
    | let doc: JsonType =>
      // A set of valid paths — none should crash
      let paths: Array[String] val = [
        "$"
        "$.*"
        "$.a"
        "$[0]"
        "$[-1]"
        "$[*]"
        "$..a"
        "$..*"
        "$[0:2]"
        "$[:2]"
        "$[1:]"
        "$.a.b"
        "$.a[0]"
        "$[0,1]"
        "$[0:2:1]"
        "$[::2]"
        "$[::-1]"
        "$[::0]"
        "$[1::-1]"
      ]
      for path_str in paths.values() do
        try
          let path = JsonPathParser.compile(path_str)?
          // query should never crash — it returns an array (possibly empty)
          let results = path.query(doc)
          // Just verify we got an array back (size >= 0)
          ph.assert_true(results.size() >= 0)
        else
          ph.fail("Failed to compile known-valid path: " + path_str)
        end
      end
    | let _: JsonParseError =>
      // Generator produced invalid JSON — shouldn't happen but skip
      None
    end

// ===================================================================
// Example Tests — Parser Success
// ===================================================================

class \nodoc\ iso _TestParseKeywords is UnitTest
  fun name(): String => "json/parse/keywords"

  fun apply(h: TestHelper) ? =>
    match JsonParser.parse("true")
    | let j: JsonType => h.assert_eq[Bool](true, j as Bool)
    else h.fail("true failed to parse")
    end

    match JsonParser.parse("false")
    | let j: JsonType => h.assert_eq[Bool](false, j as Bool)
    else h.fail("false failed to parse")
    end

    match JsonParser.parse("null")
    | let j: JsonType =>
      match j
      | JsonNull => None // pass
      else h.fail("null parsed as wrong type")
      end
    else h.fail("null failed to parse")
    end

class \nodoc\ iso _TestParseNumbers is UnitTest
  fun name(): String => "json/parse/numbers"

  fun apply(h: TestHelper) ? =>
    // Integers
    match JsonParser.parse("0")
    | let j: JsonType => h.assert_eq[I64](0, j as I64)
    else h.fail("0 failed")
    end

    match JsonParser.parse("42")
    | let j: JsonType => h.assert_eq[I64](42, j as I64)
    else h.fail("42 failed")
    end

    match JsonParser.parse("-1")
    | let j: JsonType => h.assert_eq[I64](-1, j as I64)
    else h.fail("-1 failed")
    end

    // Floats
    match JsonParser.parse("3.14")
    | let j: JsonType =>
      let f = j as F64
      h.assert_true((f - 3.14).abs() < 1e-10)
    else h.fail("3.14 failed")
    end

    match JsonParser.parse("1e10")
    | let j: JsonType =>
      let f = j as F64
      h.assert_true((f - 1e10).abs() < 1.0)
    else h.fail("1e10 failed")
    end

    match JsonParser.parse("1.5e-3")
    | let j: JsonType =>
      let f = j as F64
      h.assert_true((f - 0.0015).abs() < 1e-10)
    else h.fail("1.5e-3 failed")
    end

    match JsonParser.parse("-0.5")
    | let j: JsonType =>
      let f = j as F64
      h.assert_true((f - (-0.5)).abs() < 1e-10)
    else h.fail("-0.5 failed")
    end

    // Large integer promoted to F64 instead of overflowing
    match JsonParser.parse("99999999999999999999")
    | let j: JsonType =>
      let f = j as F64
      h.assert_true(f > 9.99e18)
    else h.fail("large integer failed")
    end

    // Zero alone is valid
    match JsonParser.parse("0")
    | let j: JsonType => h.assert_eq[I64](0, j as I64)
    else h.fail("standalone 0 failed")
    end

    // 0.5 is valid (zero before decimal)
    match JsonParser.parse("0.5")
    | let j: JsonType =>
      let f = j as F64
      h.assert_true((f - 0.5).abs() < 1e-10)
    else h.fail("0.5 failed")
    end

class \nodoc\ iso _TestParseStrings is UnitTest
  fun name(): String => "json/parse/strings"

  fun apply(h: TestHelper) ? =>
    // Simple string
    match JsonParser.parse("\"hello\"")
    | let j: JsonType => h.assert_eq[String]("hello", j as String)
    else h.fail("simple string failed")
    end

    // All basic escape sequences
    match JsonParser.parse("\"a\\nb\\tc\\\"d\\\\e\\/f\"")
    | let j: JsonType =>
      let s = j as String
      h.assert_eq[String]("a\nb\tc\"d\\e/f", s)
    else h.fail("escape sequences failed")
    end

    // \b and \f
    match JsonParser.parse("\"\\b\\f\"")
    | let j: JsonType =>
      let s = j as String
      h.assert_eq[U8](0x08, try s(0)? else 0 end)
      h.assert_eq[U8](0x0C, try s(1)? else 0 end)
    else h.fail("\\b\\f failed")
    end

    // \r
    match JsonParser.parse("\"\\r\"")
    | let j: JsonType =>
      h.assert_eq[String]("\r", j as String)
    else h.fail("\\r failed")
    end

    // Unicode BMP: \u00E9 = é
    match JsonParser.parse("\"\\u00E9\"")
    | let j: JsonType =>
      let s = j as String
      let expected = recover val String.from_utf32(0xE9) end
      h.assert_eq[String](expected, s)
    else h.fail("unicode BMP failed")
    end

    // Surrogate pair: \uD834\uDD1E = U+1D11E (musical symbol G clef)
    match JsonParser.parse("\"\\uD834\\uDD1E\"")
    | let j: JsonType =>
      let s = j as String
      let expected = recover val String.from_utf32(0x1D11E) end
      h.assert_eq[String](expected, s)
    else h.fail("surrogate pair failed")
    end

    // Control char via unicode escape: \u001F
    match JsonParser.parse("\"\\u001F\"")
    | let j: JsonType =>
      let s = j as String
      h.assert_eq[USize](1, s.size())
      h.assert_eq[U8](0x1F, try s(0)? else 0 end)
    else h.fail("control char escape failed")
    end

class \nodoc\ iso _TestParseContainers is UnitTest
  fun name(): String => "json/parse/containers"

  fun apply(h: TestHelper) ? =>
    // Empty object
    match JsonParser.parse("{}")
    | let j: JsonType =>
      let obj = j as JsonObject
      h.assert_eq[USize](0, obj.size())
    else h.fail("empty object failed")
    end

    // Empty array
    match JsonParser.parse("[]")
    | let j: JsonType =>
      let arr = j as JsonArray
      h.assert_eq[USize](0, arr.size())
    else h.fail("empty array failed")
    end

    // Nested structure
    match JsonParser.parse("""{"a":{"b":[1,2]}}""")
    | let j: JsonType =>
      let nav = JsonNav(j)
      h.assert_eq[I64](1, nav("a")("b")(USize(0)).as_i64()?)
      h.assert_eq[I64](2, nav("a")("b")(USize(1)).as_i64()?)
    else h.fail("nested structure failed")
    end

    // Whitespace between tokens
    match JsonParser.parse("  { \"a\" :  1  ,  \"b\" :  2  }  ")
    | let j: JsonType =>
      let obj = j as JsonObject
      h.assert_eq[USize](2, obj.size())
    else h.fail("whitespace handling failed")
    end

class \nodoc\ iso _TestParseWholeDocument is UnitTest
  fun name(): String => "json/parse/whole-document"

  fun apply(h: TestHelper) ? =>
    let src =
      """
      {"store":{"book":[{"title":"A","author":"X","price":10},{"title":"B","author":"Y","price":20}],"bicycle":{"color":"red","price":15}}}
      """
    match JsonParser.parse(src)
    | let j: JsonType =>
      let nav = JsonNav(j)
      h.assert_eq[String]("A", nav("store")("book")(USize(0))("title").as_string()?)
      h.assert_eq[String]("Y", nav("store")("book")(USize(1))("author").as_string()?)
      h.assert_eq[I64](15, nav("store")("bicycle")("price").as_i64()?)
      h.assert_eq[String]("red", nav("store")("bicycle")("color").as_string()?)
    | let e: JsonParseError =>
      h.fail("Whole document parse failed: " + e.string())
    end

// ===================================================================
// Example Tests — Parser Errors
// ===================================================================

class \nodoc\ iso _TestParseErrors is UnitTest
  fun name(): String => "json/parse/errors"

  fun apply(h: TestHelper) =>
    _assert_parse_error(h, "", "empty input")
    _assert_parse_error(h, "hello", "bare word")
    _assert_parse_error(h, """{"a":1,}""", "trailing comma in object")
    _assert_parse_error(h, "[1,]", "trailing comma in array")
    _assert_parse_error(h, """{"a":1""", "unclosed object")
    _assert_parse_error(h, "[1", "unclosed array")
    _assert_parse_error(h, "\"hello", "unterminated string")
    _assert_parse_error(h, "\"\\x\"", "bad escape")
    _assert_parse_error(h, "1 2", "trailing content")
    _assert_parse_error(h, "\"\\u00GG\"", "bad unicode hex")

    // Leading zeros (RFC 8259)
    _assert_parse_error(h, "01", "leading zero")
    _assert_parse_error(h, "007", "leading zeros")
    _assert_parse_error(h, "00", "double zero")
    _assert_parse_error(h, "-01", "negative leading zero")

    // Raw control char (byte < 0x20)
    let ctrl = recover val
      let s = String(3)
      s.push('"')
      s.push(0x01)
      s.push('"')
      s
    end
    _assert_parse_error(h, ctrl, "raw control char")

  fun _assert_parse_error(h: TestHelper, input: String, label: String) =>
    match JsonParser.parse(input)
    | let _: JsonParseError => None // expected
    | let _: JsonType => h.fail("Expected error for: " + label)
    end

class \nodoc\ iso _TestParseErrorLoneSurrogates is UnitTest
  fun name(): String => "json/parse/lone-surrogates"

  fun apply(h: TestHelper) =>
    // High surrogate without low
    _assert_parse_error(h, "\"\\uD800\"", "high surrogate alone")

    // Lone low surrogate
    _assert_parse_error(h, "\"\\uDC00\"", "lone low surrogate")

    // High surrogate followed by non-surrogate
    _assert_parse_error(h, "\"\\uD800\\u0041\"", "high + non-surrogate")

  fun _assert_parse_error(h: TestHelper, input: String, label: String) =>
    match JsonParser.parse(input)
    | let _: JsonParseError => None // expected
    | let _: JsonType => h.fail("Expected error for: " + label)
    end

// ===================================================================
// Example Tests — Serialization
// ===================================================================

class \nodoc\ iso _TestPrintCompact is UnitTest
  fun name(): String => "json/print/compact"

  fun apply(h: TestHelper) =>
    // Empty containers
    h.assert_eq[String]("{}", JsonObject.string())
    h.assert_eq[String]("[]", JsonArray.string())

    // Object with entries
    let obj = JsonObject.update("a", I64(1))
    let obj_s: String val = obj.string()
    h.assert_eq[String]("""{"a":1}""", obj_s)

    // Array with entries
    let arr = JsonArray.push(I64(1)).push(I64(2))
    let arr_s: String val = arr.string()
    h.assert_eq[String]("[1,2]", arr_s)

    // Boolean, null via array
    let mixed = JsonArray
      .push(true)
      .push(false)
      .push(JsonNull)
    let mixed_s: String val = mixed.string()
    h.assert_eq[String]("[true,false,null]", mixed_s)

    // String with special chars
    let str_arr = JsonArray.push("a\"b\\c\nd")
    let str_s: String val = str_arr.string()
    h.assert_eq[String]("""["a\"b\\c\nd"]""", str_s)

class \nodoc\ iso _TestPrintPretty is UnitTest
  fun name(): String => "json/print/pretty"

  fun apply(h: TestHelper) =>
    // Empty containers stay compact
    h.assert_eq[String]("{}", JsonObject.pretty_string())
    h.assert_eq[String]("[]", JsonArray.pretty_string())

    // Simple object
    let obj = JsonObject.update("a", I64(1))
    let expected = "{\n  \"a\": 1\n}"
    h.assert_eq[String](expected, obj.pretty_string())

    // Nested
    let inner = JsonObject.update("x", I64(42))
    let outer = JsonObject.update("inner", inner)
    let nested_s: String val = outer.pretty_string()
    h.assert_true(nested_s.contains("    \"x\": 42"))

    // Custom indent
    let tab_s: String val = obj.pretty_string("\t")
    h.assert_true(tab_s.contains("\t\"a\": 1"))

    // Array
    let arr = JsonArray.push(I64(1)).push(I64(2))
    let arr_s: String val = arr.pretty_string()
    let arr_expected = "[\n  1,\n  2\n]"
    h.assert_eq[String](arr_expected, arr_s)

class \nodoc\ iso _TestPrintFloats is UnitTest
  fun name(): String => "json/print/floats"

  fun apply(h: TestHelper) =>
    // Whole-number float gets .0 suffix
    let whole = JsonArray.push(F64(1))
    let whole_s: String val = whole.string()
    h.assert_eq[String]("[1.0]", whole_s)

    // Decimal float kept as-is
    let dec = JsonArray.push(F64(1.5))
    let dec_s: String val = dec.string()
    h.assert_eq[String]("[1.5]", dec_s)

    // Negative float
    let neg = JsonArray.push(F64(-3.25))
    let neg_s: String val = neg.string()
    h.assert_eq[String]("[-3.25]", neg_s)

    // Zero
    let zero = JsonArray.push(F64(0))
    let zero_s: String val = zero.string()
    h.assert_eq[String]("[0.0]", zero_s)

// ===================================================================
// Example Tests — Collections
// ===================================================================

class \nodoc\ iso _TestObjectGetOrElse is UnitTest
  fun name(): String => "json/object/get-or-else"

  fun apply(h: TestHelper) ? =>
    let obj = JsonObject.update("key", I64(42))

    // Present key returns stored value
    let got = obj.get_or_else("key", I64(0)) as I64
    h.assert_eq[I64](42, got)

    // Missing key returns default
    let missing = obj.get_or_else("nope", I64(99)) as I64
    h.assert_eq[I64](99, missing)

    // Default can be different type than stored
    let str_default = obj.get_or_else("nope", "default") as String
    h.assert_eq[String]("default", str_default)

class \nodoc\ iso _TestArrayUpdate is UnitTest
  fun name(): String => "json/array/update"

  fun apply(h: TestHelper) ? =>
    let arr = JsonArray.push(I64(1)).push(I64(2)).push(I64(3))

    // Update replaces element
    let updated = arr.update(1, I64(99))?
    h.assert_eq[I64](99, updated(1)? as I64)

    // Original unchanged
    h.assert_eq[I64](2, arr(1)? as I64)

    // Other elements preserved
    h.assert_eq[I64](1, updated(0)? as I64)
    h.assert_eq[I64](3, updated(2)? as I64)

    // Out of bounds raises
    h.assert_error({() ? => arr.update(10, I64(0))? })

// ===================================================================
// Example Tests — Navigation
// ===================================================================

class \nodoc\ iso _TestNavSuccess is UnitTest
  fun name(): String => "json/nav/success"

  fun apply(h: TestHelper) ? =>
    let doc = JsonObject
      .update("name", "Alice")
      .update("age", I64(30))
      .update("score", F64(9.5))
      .update("active", true)
      .update("data", JsonNull)
      .update("tags", JsonArray.push("a").push("b"))
      .update("meta", JsonObject.update("x", I64(1)))

    let nav = JsonNav(doc)

    // Object key lookup
    h.assert_eq[String]("Alice", nav("name").as_string()?)

    // Chained navigation
    h.assert_eq[I64](1, nav("meta")("x").as_i64()?)

    // Array index
    h.assert_eq[String]("a", nav("tags")(USize(0)).as_string()?)

    // All terminal extractors
    h.assert_eq[String]("Alice", nav("name").as_string()?)
    h.assert_eq[I64](30, nav("age").as_i64()?)
    h.assert_eq[F64](9.5, nav("score").as_f64()?)
    h.assert_eq[Bool](true, nav("active").as_bool()?)
    nav("data").as_null()?  // should not raise
    nav("meta").as_object()?  // should not raise
    nav("tags").as_array()?  // should not raise

class \nodoc\ iso _TestNavNotFound is UnitTest
  fun name(): String => "json/nav/not-found"

  fun apply(h: TestHelper) =>
    let obj = JsonObject.update("a", I64(1))
    let arr = JsonArray.push(I64(1))
    let nav_obj = JsonNav(obj)
    let nav_arr = JsonNav(arr)

    // Missing key
    h.assert_false(nav_obj("missing").found())

    // Out of bounds index
    h.assert_false(nav_arr(USize(99)).found())

    // Type mismatch: string key on array
    h.assert_false(nav_arr("key").found())

    // Type mismatch: index on object
    h.assert_false(nav_obj(USize(0)).found())

    // NotFound propagates through chain
    h.assert_false(nav_obj("x")("y")("z").found())

    // Extractor on NotFound raises
    h.assert_error({() ? => nav_obj("missing").as_string()? })

class \nodoc\ iso _TestNavInspection is UnitTest
  fun name(): String => "json/nav/inspection"

  fun apply(h: TestHelper) ? =>
    let obj = JsonObject.update("a", I64(1)).update("b", I64(2))
    let arr = JsonArray.push(I64(1)).push(I64(2)).push(I64(3))

    // found()
    h.assert_true(JsonNav(obj).found())
    h.assert_false(JsonNav(obj)("missing").found())

    // size() on object and array
    h.assert_eq[USize](2, JsonNav(obj).size()?)
    h.assert_eq[USize](3, JsonNav(arr).size()?)

    // size() raises on non-container
    h.assert_error({() ? => JsonNav(I64(1)).size()? })

    // json() returns raw value
    match JsonNav(obj).json()
    | let o: JsonObject => h.assert_eq[USize](2, o.size())
    else h.fail("json() returned wrong type")
    end

    match JsonNav(obj)("missing").json()
    | NotFound => None // expected
    else h.fail("Expected NotFound from json()")
    end

// ===================================================================
// Example Tests — Lens
// ===================================================================

class \nodoc\ iso _TestLensGet is UnitTest
  fun name(): String => "json/lens/get"

  fun apply(h: TestHelper) ? =>
    let doc = JsonObject
      .update("a", JsonObject.update("b", I64(42)))

    // Identity lens returns root
    match JsonLens.get(doc)
    | let j: JsonType =>
      let obj = j as JsonObject
      h.assert_true(obj.contains("a"))
    else h.fail("Identity get failed")
    end

    // Nested path
    let lens = JsonLens("a")("b")
    match lens.get(doc)
    | let j: JsonType => h.assert_eq[I64](42, j as I64)
    else h.fail("Nested get failed")
    end

    // Missing intermediate -> NotFound
    let missing = JsonLens("x")("y")
    match missing.get(doc)
    | NotFound => None
    else h.fail("Expected NotFound for missing path")
    end

    // Type mismatch -> NotFound
    let mismatch = JsonLens("a")("b")("c")
    match mismatch.get(doc)
    | NotFound => None
    else h.fail("Expected NotFound for type mismatch")
    end

class \nodoc\ iso _TestLensSet is UnitTest
  fun name(): String => "json/lens/set"

  fun apply(h: TestHelper) ? =>
    let doc = JsonObject
      .update("a", JsonObject
        .update("b", I64(1))
        .update("c", I64(2)))

    // Identity lens replaces root
    match JsonLens.set(doc, I64(99))
    | let j: JsonType => h.assert_eq[I64](99, j as I64)
    else h.fail("Identity set failed")
    end

    // Nested set
    let lens = JsonLens("a")("b")
    match lens.set(doc, I64(42))
    | let j: JsonType =>
      let nav = JsonNav(j)
      h.assert_eq[I64](42, nav("a")("b").as_i64()?)
      // Sibling preserved
      h.assert_eq[I64](2, nav("a")("c").as_i64()?)
    else h.fail("Nested set failed")
    end

    // Original unchanged
    let nav = JsonNav(doc)
    h.assert_eq[I64](1, nav("a")("b").as_i64()?)

    // Missing intermediate -> NotFound
    let missing = JsonLens("x")("y")
    match missing.set(doc, I64(1))
    | NotFound => None
    else h.fail("Expected NotFound for missing intermediate")
    end

class \nodoc\ iso _TestLensRemove is UnitTest
  fun name(): String => "json/lens/remove"

  fun apply(h: TestHelper) ? =>
    let doc = JsonObject
      .update("a", JsonObject
        .update("b", I64(1))
        .update("c", I64(2)))

    // Remove key
    let lens = JsonLens("a")("b")
    match lens.remove(doc)
    | let j: JsonType =>
      let nav = JsonNav(j)
      h.assert_false(nav("a")("b").found())
      // Sibling preserved
      h.assert_eq[I64](2, nav("a")("c").as_i64()?)
    else h.fail("Remove failed")
    end

    // Remove on array index -> NotFound
    let arr_doc = JsonObject.update("arr", JsonArray.push(I64(1)))
    let arr_lens = JsonLens("arr")(USize(0))
    match arr_lens.remove(arr_doc)
    | NotFound => None
    else h.fail("Expected NotFound for array index remove")
    end

class \nodoc\ iso _TestLensComposition is UnitTest
  fun name(): String => "json/lens/composition"

  fun apply(h: TestHelper) ? =>
    let doc = JsonObject
      .update("a", JsonObject
        .update("b", JsonObject
          .update("c", I64(99))))

    // compose equivalent to chained apply
    let lens_ab = JsonLens("a")("b")
    let lens_c = JsonLens("c")
    let composed = lens_ab.compose(lens_c)
    let chained = JsonLens("a")("b")("c")

    match composed.get(doc)
    | let j1: JsonType =>
      match chained.get(doc)
      | let j2: JsonType =>
        h.assert_eq[I64](j1 as I64, j2 as I64)
      else h.fail("Chained get failed")
      end
    else h.fail("Composed get failed")
    end

    // or_else falls back when first lens fails
    let missing = JsonLens("x")
    let found = JsonLens("a")("b")("c")
    let fallback = missing.or_else(found)
    match fallback.get(doc)
    | let j: JsonType => h.assert_eq[I64](99, j as I64)
    else h.fail("or_else fallback failed")
    end

    // or_else uses first when it succeeds
    let first_wins = found.or_else(missing)
    match first_wins.get(doc)
    | let j: JsonType => h.assert_eq[I64](99, j as I64)
    else h.fail("or_else first-match failed")
    end

    // Composed set modifies deeply nested value
    match composed.set(doc, I64(0))
    | let j: JsonType =>
      let nav = JsonNav(j)
      h.assert_eq[I64](0, nav("a")("b")("c").as_i64()?)
    else h.fail("Composed set failed")
    end

// ===================================================================
// Example Tests — JSONPath
// ===================================================================

class \nodoc\ iso _TestJsonPathParse is UnitTest
  fun name(): String => "json/jsonpath/parse"

  fun apply(h: TestHelper) =>
    // All valid expressions should parse
    let valid: Array[String] val = [
      "$"
      "$.name"
      "$['name']"
      """$["name"]"""
      "$[0]"
      "$[-1]"
      "$.*"
      "$[*]"
      "$..name"
      "$..*"
      "$[0:2]"
      "$[:2]"
      "$[1:]"
      "$[0,1,2]"
      "$.store.book[*].author"
      "$[0:2:1]"
      "$[::2]"
      "$[::-1]"
      "$[1:4:2]"
      "$[::0]"
    ]
    for path_str in valid.values() do
      match JsonPathParser.parse(path_str)
      | let _: JsonPath => None // pass
      | let e: JsonPathParseError =>
        h.fail("Expected valid: " + path_str + " — " + e.string())
      end
    end

    // compile raises on bad input
    h.assert_error({() ? => JsonPathParser.compile("invalid")? })

    // compile succeeds on good input
    try
      JsonPathParser.compile("$.a")?
    else
      h.fail("compile should succeed for $.a")
    end

class \nodoc\ iso _TestJsonPathParseErrors is UnitTest
  fun name(): String => "json/jsonpath/parse-errors"

  fun apply(h: TestHelper) =>
    let invalid: Array[String] val = [
      ""         // empty string
      "name"     // missing $
      "$!"       // bad segment char
      "$[0"      // unclosed bracket
      "$['open"  // unterminated string
    ]
    for path_str in invalid.values() do
      match JsonPathParser.parse(path_str)
      | let _: JsonPathParseError => None // expected
      | let _: JsonPath =>
        h.fail("Expected error for: " + path_str)
      end
    end

class \nodoc\ iso _TestJsonPathQueryBasic is UnitTest
  fun name(): String => "json/jsonpath/query/basic"

  fun apply(h: TestHelper) ? =>
    let doc = JsonObject
      .update("a", I64(1))
      .update("b", JsonObject.update("c", I64(2)))

    let arr_doc = JsonArray
      .push(I64(10))
      .push(I64(20))
      .push(I64(30))

    // Dot child
    let p1 = JsonPathParser.compile("$.a")?
    let r1 = p1.query(doc)
    h.assert_eq[USize](1, r1.size())
    h.assert_eq[I64](1, r1(0)? as I64)

    // Nested dots
    let p2 = JsonPathParser.compile("$.b.c")?
    let r2 = p2.query(doc)
    h.assert_eq[USize](1, r2.size())
    h.assert_eq[I64](2, r2(0)? as I64)

    // Index
    let p3 = JsonPathParser.compile("$[0]")?
    let r3 = p3.query(arr_doc)
    h.assert_eq[USize](1, r3.size())
    h.assert_eq[I64](10, r3(0)? as I64)

    // Negative index
    let p4 = JsonPathParser.compile("$[-1]")?
    let r4 = p4.query(arr_doc)
    h.assert_eq[USize](1, r4.size())
    h.assert_eq[I64](30, r4(0)? as I64)

    // Missing key -> empty
    let p5 = JsonPathParser.compile("$.missing")?
    let r5 = p5.query(doc)
    h.assert_eq[USize](0, r5.size())

    // Type mismatch -> empty
    let p6 = JsonPathParser.compile("$.a")?
    let r6 = p6.query(arr_doc)
    h.assert_eq[USize](0, r6.size())

    // query_one returns first
    match p1.query_one(doc)
    | let j: JsonType => h.assert_eq[I64](1, j as I64)
    else h.fail("query_one should find $.a")
    end

    // query_one returns NotFound when empty
    match p5.query_one(doc)
    | NotFound => None
    else h.fail("query_one should return NotFound for missing")
    end

class \nodoc\ iso _TestJsonPathQueryAdvanced is UnitTest
  fun name(): String => "json/jsonpath/query/advanced"

  fun apply(h: TestHelper) ? =>
    let doc = JsonObject
      .update("a", I64(1))
      .update("b", I64(2))
      .update("c", JsonObject.update("a", I64(3)))

    let arr = JsonArray
      .push(I64(10))
      .push(I64(20))
      .push(I64(30))
      .push(I64(40))

    // Wildcard on object
    let p1 = JsonPathParser.compile("$.*")?
    let r1 = p1.query(doc)
    h.assert_eq[USize](3, r1.size())

    // Wildcard on array
    let p2 = JsonPathParser.compile("$[*]")?
    let r2 = p2.query(arr)
    h.assert_eq[USize](4, r2.size())

    // Recursive descent
    let p3 = JsonPathParser.compile("$..a")?
    let r3 = p3.query(doc)
    // Should find doc.a (1) and doc.c.a (3)
    h.assert_eq[USize](2, r3.size())

    // Slice [0:2]
    let p4 = JsonPathParser.compile("$[0:2]")?
    let r4 = p4.query(arr)
    h.assert_eq[USize](2, r4.size())
    h.assert_eq[I64](10, r4(0)? as I64)
    h.assert_eq[I64](20, r4(1)? as I64)

    // Open-ended slices
    let p5 = JsonPathParser.compile("$[:2]")?
    let r5 = p5.query(arr)
    h.assert_eq[USize](2, r5.size())

    let p6 = JsonPathParser.compile("$[1:]")?
    let r6 = p6.query(arr)
    h.assert_eq[USize](3, r6.size())
    h.assert_eq[I64](20, r6(0)? as I64)

    // Negative slice
    let p7 = JsonPathParser.compile("$[-2:]")?
    let r7 = p7.query(arr)
    h.assert_eq[USize](2, r7.size())
    h.assert_eq[I64](30, r7(0)? as I64)
    h.assert_eq[I64](40, r7(1)? as I64)

    // Union
    let p8 = JsonPathParser.compile("$[0,2]")?
    let r8 = p8.query(arr)
    h.assert_eq[USize](2, r8.size())
    h.assert_eq[I64](10, r8(0)? as I64)
    h.assert_eq[I64](30, r8(1)? as I64)

    // Descendant wildcard
    let p9 = JsonPathParser.compile("$..*")?
    let r9 = p9.query(doc)
    // Should include all values at all levels
    h.assert_true(r9.size() > 0)

class \nodoc\ iso _TestJsonPathQueryComplex is UnitTest
  fun name(): String => "json/jsonpath/query/complex"

  fun apply(h: TestHelper) ? =>
    let book1 = JsonObject
      .update("title", "A")
      .update("author", "X")
      .update("price", I64(10))

    let book2 = JsonObject
      .update("title", "B")
      .update("author", "Y")
      .update("price", I64(20))

    let bicycle = JsonObject
      .update("color", "red")
      .update("price", I64(15))

    let store = JsonObject
      .update("book", JsonArray.push(book1).push(book2))
      .update("bicycle", bicycle)

    let doc = JsonObject.update("store", store)

    // All book authors
    let p1 = JsonPathParser.compile("$.store.book[*].author")?
    let r1 = p1.query(doc)
    h.assert_eq[USize](2, r1.size())

    // All prices (recursive descent)
    let p2 = JsonPathParser.compile("$.store..price")?
    let r2 = p2.query(doc)
    // 2 book prices + 1 bicycle price = 3
    h.assert_eq[USize](3, r2.size())

    // First book title
    let p3 = JsonPathParser.compile("$.store.book[0].title")?
    match p3.query_one(doc)
    | let j: JsonType => h.assert_eq[String]("A", j as String)
    else h.fail("Should find first book title")
    end

class \nodoc\ iso _TestJsonPathQuerySliceStep is UnitTest
  fun name(): String => "json/jsonpath/query/slice-step"

  fun apply(h: TestHelper) ? =>
    let arr = JsonArray
      .push(I64(10))
      .push(I64(20))
      .push(I64(30))
      .push(I64(40))
      .push(I64(50))

    // Positive step: every other element [0:5:2] -> [10, 30, 50]
    let p1 = JsonPathParser.compile("$[0:5:2]")?
    let r1 = p1.query(arr)
    h.assert_eq[USize](3, r1.size())
    h.assert_eq[I64](10, r1(0)? as I64)
    h.assert_eq[I64](30, r1(1)? as I64)
    h.assert_eq[I64](50, r1(2)? as I64)

    // Step=1 explicit same as omitted [1:4:1] -> [20, 30, 40]
    let p2 = JsonPathParser.compile("$[1:4:1]")?
    let r2 = p2.query(arr)
    h.assert_eq[USize](3, r2.size())
    h.assert_eq[I64](20, r2(0)? as I64)

    // Negative step: reverse [4:1:-1] -> [50, 40, 30]
    let p3 = JsonPathParser.compile("$[4:1:-1]")?
    let r3 = p3.query(arr)
    h.assert_eq[USize](3, r3.size())
    h.assert_eq[I64](50, r3(0)? as I64)
    h.assert_eq[I64](40, r3(1)? as I64)
    h.assert_eq[I64](30, r3(2)? as I64)

    // Negative step with defaults: reverse entire array [::-1]
    let p4 = JsonPathParser.compile("$[::-1]")?
    let r4 = p4.query(arr)
    h.assert_eq[USize](5, r4.size())
    h.assert_eq[I64](50, r4(0)? as I64)
    h.assert_eq[I64](10, r4(4)? as I64)

    // Step=0 produces no results
    let p5 = JsonPathParser.compile("$[::0]")?
    let r5 = p5.query(arr)
    h.assert_eq[USize](0, r5.size())

    // Negative indices with step: [-4:-1:2] -> [20, 40]
    let p6 = JsonPathParser.compile("$[-4:-1:2]")?
    let r6 = p6.query(arr)
    h.assert_eq[USize](2, r6.size())
    h.assert_eq[I64](20, r6(0)? as I64)
    h.assert_eq[I64](40, r6(1)? as I64)

    // Step with open start/end: [::2] -> [10, 30, 50]
    let p7 = JsonPathParser.compile("$[::2]")?
    let r7 = p7.query(arr)
    h.assert_eq[USize](3, r7.size())
    h.assert_eq[I64](10, r7(0)? as I64)
    h.assert_eq[I64](30, r7(1)? as I64)
    h.assert_eq[I64](50, r7(2)? as I64)

    // Negative step, open start/end: [::-2] -> [50, 30, 10]
    let p8 = JsonPathParser.compile("$[::-2]")?
    let r8 = p8.query(arr)
    h.assert_eq[USize](3, r8.size())
    h.assert_eq[I64](50, r8(0)? as I64)
    h.assert_eq[I64](30, r8(1)? as I64)
    h.assert_eq[I64](10, r8(2)? as I64)

    // Wrong direction: positive step, start > end -> empty
    let p9 = JsonPathParser.compile("$[3:1:1]")?
    let r9 = p9.query(arr)
    h.assert_eq[USize](0, r9.size())

    // Wrong direction: negative step, start < end -> empty
    let p10 = JsonPathParser.compile("$[1:3:-1]")?
    let r10 = p10.query(arr)
    h.assert_eq[USize](0, r10.size())

    // Empty array
    let empty = JsonArray
    let p11 = JsonPathParser.compile("$[::2]")?
    let r11 = p11.query(empty)
    h.assert_eq[USize](0, r11.size())

    // Slice on non-array produces empty result
    let obj = JsonObject.update("a", I64(1))
    let p12 = JsonPathParser.compile("$[::2]")?
    let r12 = p12.query(obj)
    h.assert_eq[USize](0, r12.size())

// ===================================================================
// Example Tests — Token Parser
// ===================================================================

class \nodoc\ iso _TestTokenParserAbort is UnitTest
  fun name(): String => "json/tokenparser/abort"

  fun apply(h: TestHelper) =>
    let parser = JsonTokenParser(
      object is JsonTokenNotify
        var _count: USize = 0
        fun ref apply(parser': JsonTokenParser, token: JsonToken) =>
          _count = _count + 1
          if _count >= 2 then
            parser'.abort()
          end
      end)
    // parse should raise because abort() was called mid-document
    var raised = false
    try
      parser.parse("[1,2,3]")?
    else
      raised = true
    end
    h.assert_true(raised)
