## Replace JsonNull with None

JSON null is now represented by Pony's built-in `None` instead of a custom `JsonNull` primitive. This was made possible by a fix to Pony's persistent `HashMap` (ponyc #4833) that previously used `None` as an internal sentinel.

Before:

```pony
use json = "json"

let doc = json.JsonObject.update("key", json.JsonNull)

match value
| json.JsonNull => // handle null
end
```

After:

```pony
use json = "json"

let doc = json.JsonObject.update("key", None)

match value
| None => // handle null
end
```

