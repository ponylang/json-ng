## Add slice-with-step support to JSONPath

JSONPath slice expressions now support the optional step parameter from RFC 9535: `[start:end:step]`. The step controls which elements are selected and in what order.

```pony
let doc = JsonArray.push(I64(0)).push(I64(1)).push(I64(2))
  .push(I64(3)).push(I64(4))

// Every other element
let evens = JsonPathParser.compile("$[::2]")?
evens.query(doc) // [0, 2, 4]

// Reverse the array
let rev = JsonPathParser.compile("$[::-1]")?
rev.query(doc) // [4, 3, 2, 1, 0]

// Every other element in reverse
let rev2 = JsonPathParser.compile("$[::-2]")?
rev2.query(doc) // [4, 2, 0]
```

Positive steps select forward, negative steps select in reverse, and step=0 produces no results. When step is omitted, the existing behavior (step=1) is unchanged.

