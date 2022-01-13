# LogicalFile

A LogicalFile is a facade that appears to be a contiguous file of lines of
text but which is actually composed of sections that may come from different
backing text files.

The LogicalFile preserves the mapping of a logical line to the section and
local line number that the line is provided by.

LogicalFile provides functions for modifying & updating the text while
preserving the backing structure. For example it supports inserting a new
file within the LogicalFile.

LogicalFile supports a system of Macros to process the text and includes
sample implementations of a line-comment and include macro.

An example use case is a compiler for a language with support for including
one source file from another. The LogicalFile represents the entire source to
be compiled while preserving the relationship to the indivdual source files
to faciliate error reporting.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `logical_file` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:logical_file, "~> 1.0.0"}
  ]
end
```

## Examples

```elixir
alias LogicalFile

file =
  LogicalFile.read("lib", "foo.src")
  |> LogicalFile.insert("bar.src", 25))
```

### Documentation

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/logical_file>.
