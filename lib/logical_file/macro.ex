defmodule LogicalFile.Macro do
  alias LogicalFile

  @moduledoc """
  A `Macro` represents a `LogicalFile` transformation.

  Each `Macro` is implemented by a module through the `apply_macro` callback
  with zero or more arguments in a keyword list.

  A '`Macro` invocation' is specified as a tuple in the form
  `{module, [options keyword list]}`. A macro is called through the
  `apply_macro` callback which takes a `LogicalFile` and returns a
  possibly transformed `LogicalFile`.

  The macro processor applies macros in turn to a base `LogicalFile` and each
  macro is expected to return a valid `LogicalFile`.

  Sample macro implementations are provided for handling file includes
  (`LogicalFile.Macros.Include`) and single-line comments
  (`LogicalFile.Macros.LineComment`).
  """

  @doc "generate macro invocation"
  @callback invocation(options :: list()) :: tuple()

  @doc "perform macro behaviour on a LogicalFile"
  @callback apply_macro(file :: LogicalFile.t(), options :: list()) :: LogicalFile.t()

  @doc """
  `apply_macros/2` takes a `LogicalFile` and a list of macro invocations
  and applies each macro to transform the `LogicalFile`.
  """
  def apply_macros(%LogicalFile{} = unprocessed_file, macro_list) do
    Enum.reduce(macro_list, unprocessed_file, fn {module, options}, file ->
      apply(module, :apply_macro, [file, options])
    end)
  end

end
