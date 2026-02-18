## Rename NotFound to JsonNotFound

The `NotFound` sentinel type has been renamed to `JsonNotFound` for consistency with the library's naming convention (`JsonObject`, `JsonArray`, `JsonNull`, etc.).

Before:

```pony
match lens.get(doc)
| let v: json.JsonType => // use v
| json.NotFound => // handle missing
end
```

After:

```pony
match lens.get(doc)
| let v: json.JsonType => // use v
| json.JsonNotFound => // handle missing
end
```
