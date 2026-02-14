# json-ng

An immutable JSON library for [Pony](https://www.ponylang.io/).

## Status

json-ng was created with the intent to get it included in the Pony standard library. We expect this repo will not be long for this world.

## Installation

* Install [corral](https://github.com/ponylang/corral)
* `corral add github.com/ponylang/json-ng.git --version 0.1.0`
* `corral fetch` to fetch your dependencies
* `use "json"` to include this package
* `corral run -- ponyc` to compile your application

## API Documentation

[https://ponylang.github.io/json-ng](https://ponylang.github.io/json-ng)

## Inspiration

json-ng draws inspiration from several existing libraries:

* [jay](https://github.com/patroclos/jay) — immutable JSON with lenses for Pony
* [pony-immutable-json](https://github.com/mfelsche/pony-immutable-json) — immutable JSON with builders and JSONPath for Pony
* [pony-jason](https://github.com/jemc/pony-jason) — streaming token parser for Pony
* [json](https://github.com/ponylang/json) — the current ponylang JSON library
* [serde_json](https://github.com/serde-rs/json) — Rust's widely-used JSON library
* [SwiftyJSON](https://github.com/SwiftyJSON/SwiftyJSON) — ergonomic JSON navigation for Swift
