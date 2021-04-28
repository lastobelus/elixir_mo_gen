# ElixirMoGen

More generators for Elixir/Phoenix, intended to be installed globally as an archive.

## TODO

- `mo.gen.mod` generates a generic elixir module and test. Phoenix aware, so `use`s the correct
  `test/support/*_case.ex` and omits standard Phoenix paths from namespace
- `mo.gen.gen` bootstraps a new generator

-

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `elixir_mo_gen` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:elixir_mo_gen, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/elixir_mo_gen](https://hexdocs.pm/elixir_mo_gen).
