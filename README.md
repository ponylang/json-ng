# json-ng

An immutable JSON library for [Pony](https://www.ponylang.io/).

## Status

json-ng is a new library. We expect that the API will evolve over time.

## Installation

* Install [corral](https://github.com/ponylang/corral)
* `corral add github.com/ponylang/json-ng.git --version 0.0.0`
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
