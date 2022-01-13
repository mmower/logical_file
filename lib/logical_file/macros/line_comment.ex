defmodule LogicalFile.Macros.LineComment do
  @behaviour LogicalFile.Macro

  alias LogicalFile.Section

  @moduledoc """
  A sample implementation of a macro that supports single-line comments where
  a comment expression is recognised at the beginning of a line and it
  transforms the entire content of that line into whitespace. Note that this
  does not allow a line comment to appear at the end of an expression!

  While a regular expression could be specified to recognise whitespace as part
  of the comment marker a more sophisticated implementation would allow the
  comment marker to appear after an expression. It is also left as an exercise
  to implement multi-line comments (a la C /*...*/)
  """

  @impl LogicalFile.Macro
  def apply_macro(%LogicalFile{} = file, options \\ []) do
    case Keyword.get(options, :expr) do
      nil -> raise "Cannot process comment macros without expression (:expr)!"
      expr -> process_comments(file, expr)
    end
  end

  @impl LogicalFile.Macro
  def invocation(options) when is_list(options) do
    case Keyword.get(options, :expr) do
      nil ->
        raise "Must specify expr: as Regex to match single line comment!"

      expr when is_struct(expr, Regex) ->
        {__MODULE__, [expr: expr]}

      _ ->
        raise "Illegal expr: must be Regex"
    end
  end

  @doc """
  The general strategy is to process sections in order.
  For each section find any line matching the expression and
  transform the entire contents of the line into whitespace.
  """
  def process_comments(%LogicalFile{} = file, %Regex{} = expr) do
    processed_sections =
      file
      |> LogicalFile.sections_in_order()
      |> Enum.map(fn section ->
        section
        |> Section.lines_matching(expr)
        |> Enum.reduce(section, fn {lno, _line}, updated_section ->
          Section.update_line(updated_section, lno, fn line -> Regex.replace(~r/./, line, " ") end)
        end)
      end)

    %{file | sections: LogicalFile.sections_to_map(processed_sections)}
  end
end
