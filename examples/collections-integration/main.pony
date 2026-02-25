// in your code these `use` statements would be:
// use "json"
// use "collections"
use "../../json"
use "collections"

actor Main
  new create(env: Env) =>
    test()

  be test() =>
    let errors_by_file = Map[String, Array[JsonValue] iso].create(4)
    errors_by_file("file.pony") = recover iso Array[JsonValue] end
    errors_by_file.upsert(
      "file.pony",
      recover iso
        [as JsonValue: JsonObject.update("message", "error")]
      end,
      {(current: Array[JsonValue] iso, provided: Array[JsonValue] iso) =>
        current.append(consume provided)
        consume current
      }
    )
