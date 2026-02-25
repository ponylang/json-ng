// in your code this `use` statement would be:
// use "json"
use "../../json"

actor Main
  let _env: Env

  new create(env: Env) =>
    _env = env
    let obj = JsonObject
      .update("a", JsonObject.update("b", "hello"))
      .update("x", "y")
    test(obj)

  be test(params: (JsonObject | JsonArray | None)) =>
    try
      let v = JsonNav(params)("a")("b").as_string()?
      _env.out.print(v)
    end
    try
      let results = JsonPathParser.compile("$['a','x']")?.query(
        params as JsonObject)
      _env.out.print(results.size().string())
    end
