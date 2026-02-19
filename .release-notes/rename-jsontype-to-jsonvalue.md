## Rename JsonType to JsonValue

The `JsonType` type alias has been renamed to `JsonValue` for clarity — it names a value, not a type category.

Before:

```pony
match JsonParser.parse(source)
| let j: json.JsonType => // use j
| let err: json.JsonParseError => // handle error
end
```

After:

```pony
match JsonParser.parse(source)
| let j: json.JsonValue => // use j
| let err: json.JsonParseError => // handle error
end
```
