# ElixirMoGen

More generators for Elixir/Phoenix, intended to be installed globally as an archive.

## Generators

- `mo.gen.mod` generates a generic elixir module and test. Phoenix aware, so `use`s the correct
  `test/support/*_case.ex` and omits standard Phoenix paths from namespace
- `mo.gen.gen` bootstraps a new generator, with option parsing and a test file setup with
the same `mix_helper.exs` used in this project

## TODO

- `mo.gen.migration` enhanced migration generator which automatically populates
migrations with the forms:
  - `add_example_to_TABLES example:string`
  - `add_example_other_example_index_to_TABLES [example,other_example]`
  - `add_unique_index_to_TABLES [col1,col2]`
  - `remove_example_from_TABLES example:string`
  - `remove_index_from_TABLES [col1,col2]`

## Installation

1. Download this repo, `cd` to it
2. run `MIX_ENV=prod mix do archive.build, archive.install`
