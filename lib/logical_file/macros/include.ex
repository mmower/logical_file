defmodule LogicalFile.Macros.Include do
  @behaviour LogicalFile.Macro

  alias LogicalFile.Section

  @moduledoc """
  A sample implementation of a macro that provides 'include file' functionality.

  It uses a regular expression to identiy include directives and inserts the
  contents of an included file into the `LogicalFile` at the appropriate place.
  It supports included files also including other files.
  """

  @impl LogicalFile.Macro
  def apply_macro(%LogicalFile{} = file, options \\ []) do
    case Keyword.get(options, :expr) do
      nil -> raise "Cannot process include macro without marker expression!"
      expr -> process_includes(file, expr)
    end
  end

  @impl LogicalFile.Macro
  def invocation(options) when is_list(options) do
    case Keyword.get(options, :expr) do
      nil -> raise "Must specify expr: as Regex to recognise include statement"
      expr when is_struct(expr, Regex) -> {__MODULE__, [expr: expr]}
      _ -> raise "Illegal expr: specification, must be Regex"
    end
  end

  @doc """
  The general strategy is to work section-by-section. Where a section includes
  a line that matches the macro expression (which must have a file named
  capture to indicate the file to be included) the line is replaced with
  blanks, the file is inserted, and the search is restarted on the existing
  section (that could have more than one include), otherwise it is restarted
  using the next section.
  """
  def process_includes(%LogicalFile{} = file, %Regex{} = expr, from_line \\ 1) do
    if not Enum.member?(Regex.names(expr), "file"), do: raise("Expression must capture 'file'!")

    case LogicalFile.section_including_line(file, from_line) do
      nil ->
        file

      section ->
        case Section.line_matching(section, expr) do
          nil ->
            # No match in this section, start processing from the next section
            process_includes(file, expr, section.range.last + 1)

          {line, macro} ->
            # Found a match, include the file and rescan from the same point
            # in case there's another include
            %{"file" => include_file_path} = Regex.named_captures(expr, macro)

            # Note for the future, we might want to replace expr instead of the whole line
            file
            |> LogicalFile.update_line(line, fn line -> Regex.replace(~r/./, line, " ") end)
            |> LogicalFile.insert(include_file_path, line)
            |> process_includes(expr, section.range.first)
        end
    end

  end
end
