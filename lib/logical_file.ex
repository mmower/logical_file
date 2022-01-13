defmodule LogicalFile do
  alias LogicalFile.{Macro, Section}

  @moduledoc """
  ## LogicalFile

  ### One file from many

  LogicalFile is a way of creating a logical representation of a unit of lines
  of text (e.g. a source code file) supplied by one or more backing files,
  presumably separate files on disk. It also provides for a system of macros
  that can transform the logical text.

  A typical use case for LogicalFile would be to implement a compiler that has
  `#include` style functionality. The compiler works on the whole text but
  can translate logical line numbers back to specific files and local line
  numbers (for example when an error occurs it can pinpoint the specific file
  and line the error arose in).
  """

  defstruct base_path: nil,
            sections: %{}

  @type t :: %__MODULE__{
          base_path: nil | binary,
          sections: map
        }

  # --- Interface ---

  @doc """
  `read/3` returns a new `LogicalFile` containing `Section`s that
  represent the contents of the file specified by `source_path` relative to
  `base_path` and as modified by the macros it is initialised with.

  Macros should implement the `LogicalFile.Macro` behaviours and should be
  specified as a list of tuples of the form `{module, [options keyword list]}`.
  See `LogicalFile.Macro` for further details.

  ## Examples
      iex> file = LogicalFile.read("test/support", "main.source")
      iex> assert 11 = LogicalFile.size(file)
  """
  def read(base_path, source_path, macros \\ [])
      when is_binary(source_path) and is_list(macros) do
    with section = Section.new(Path.join(base_path, source_path)) do
      %LogicalFile{base_path: base_path, sections: %{section.range => section}}
      |> Macro.apply_macros(macros)
    end
  end

  @doc """
  `assemble/2` returns a `LogicalFile` composed of the `Section`s specified in
  the second argument. This is mainly intended for internal use when modifying
  a `LogicalFile` during macro processing.
  """
  def assemble(base_path, sections) when is_list(sections) do
    %LogicalFile{
      base_path: base_path,
      sections: sections |> Enum.map(fn section -> {section.range, section} end) |> Enum.into(%{})
    }
  end

  @doc """
  `line/2` returns the specified logical line number from the `LogicalFile`
  at `lno`.

  ## Example
      iex> file = LogicalFile.read("test/support", "main.source")
      iex> assert "%(include.source)" = LogicalFile.line(file, 6)
  """
  def line(%LogicalFile{} = file, lno) do
    file
    |> section_including_line(lno)
    |> Section.line(lno)
  end

  @doc """
  `insert/3` inserts a new `Section` into the `LogicalFile` at the specified
  logical line number `at_line` and containing the contents of the `source_path.

  It guarantees that all sections and the logical file remains contiguous.

  ## Examples

  """
  def insert(%LogicalFile{base_path: base_path} = file, source_path, at_line)
      when is_binary(source_path) do
    insert(file, Section.new(Path.join(base_path, source_path)), at_line)
  end

  def insert(
        %LogicalFile{base_path: base_path, sections: sections},
        %Section{} = insert_section,
        at_line
      ) do
    with sections = Map.values(sections),
         {before, target, rest} = partition_sections(sections, at_line) do
      if is_nil(target),
        do: raise("Unable to partition: line:#{at_line} is not in any source section.")

      {pre, post} = Section.split(target, at_line)
      before = before ++ [pre]
      rest = [post | rest]

      insert_section = Section.shift(insert_section, Section.size(pre))

      rest =
        Enum.map(rest, fn section -> Section.shift(section, Section.size(insert_section)) end)

      LogicalFile.assemble(base_path, before ++ [insert_section] ++ rest)
    end
  end

  @doc """
  `contains_source?/2` returns true if at least one section from the given
  `LogicalFile` originates from the specified `source_path`.

  ## Examples
      iex> file = LogicalFile.read("test/support", "main.source")
      iex> assert not LogicalFile.contains_source?(file, "test/support/player.source")
      iex> assert LogicalFile.contains_source?(file, "test/support/main.source")
  """
  def contains_source?(%LogicalFile{sections: sections}, source_path) do
    Enum.any?(sections, fn {_range, section} -> section.source_path == source_path end)
  end

  @doc """
  `lines/1` returns a list of all lines in the `LogicalFile` in line number
  order.
  """
  def lines(%LogicalFile{} = file) do
    file
    |> sections_in_order()
    |> Enum.reduce([], fn section, lines -> lines ++ section.lines end)
  end

  @doc """
  `size/1` returns the number of lines in the `LogicalFile`.

  ## Examples
      iex> file = LogicalFile.read("test/support", "main.source")
      iex> 11 = LogicalFile.size(file)
  """
  def size(%LogicalFile{sections: sections}) do
    Enum.reduce(sections, 0, fn {_range, section}, size ->
      size + Section.size(section)
    end)
  end

  @doc """
  `last_line_number/1` returns the line number of the last line in the
  specified `LogicalFile`.

  ## Examples
      iex> alias LogicalFile.Section
      iex> file = LogicalFile.read("test/support", "main.source")
      iex> assert 11 = LogicalFile.last_line_number(file)
  """
  def last_line_number(%LogicalFile{} = file) do
    file
    |> sections_in_order()
    |> List.last()
    |> then(fn %Section{range: _lo..hi} -> hi end)
  end

  @doc """
  `update_line/3` replaces the content of line `lno` in the specified
  `LogicalFile` by passing the current contents of the line to the specified
  transformation function. This function is expected to return the new
  contents of the line.

  ## Examples
      iex> assert "                 " =
      ...>  LogicalFile.read("test/support", "main.source")
      ...>  |> LogicalFile.update_line(6, fn line -> String.duplicate(" ", String.length(line)) end)
      ...>  |> LogicalFile.line(6)
  """
  def update_line(%LogicalFile{sections: sections} = file, lno, fun) do
    updated_section =
      file
      |> section_including_line(lno)
      |> Section.update_line(lno, fun)

    %{file | sections: Map.put(sections, updated_section.range, updated_section)}
  end

  @doc """
  `section_including_line/2` returns the `Section` that contains the logical
  line `lno`.

  ## Examples
      iex> alias LogicalFile.Section
      iex> section1 = Section.new("test/support/main.source")
      iex> section2 = Section.new("test/support/include.source") |> Section.shift(-9)
      iex> map = LogicalFile.assemble("test/support", [section1, section2])
      iex> assert ^section1 = LogicalFile.section_including_line(map, section1.range.first)
      iex> assert ^section2 = LogicalFile.section_including_line(map, section2.range.first)
  """
  def section_including_line(%LogicalFile{} = file, lno) do
    file
    |> sections_in_order()
    |> Enum.find(fn %{range: range} -> lno in range end)
  end



  @doc """
  `resolve_line/2` takes a logical line number `logical_lno` and returns a
  tuple `{file, local_line_no}` representing the file and file line number
  that logical line represents.

  ## Examples
      iex> alias LogicalFile.Macros.Include
      iex> file = LogicalFile.read("test/support", "main.source")
      iex> assert {"test/support/main.source", 1} = LogicalFile.resolve_line(file, 1)
  """
  def resolve_line(%LogicalFile{} = file, logical_lno) do
    file
    |> section_including_line(logical_lno)
    |> Section.resolve_line(logical_lno)
  end

  # --- Utility functions ---

  @doc """
  `sections_to_map/1` takes a list of `Section`s and returns a `Map` whose
  keys are the logical line number ranges of the sections, mapped to the
  corresponding sections.
  """
  def sections_to_map(sections) do
    Enum.reduce(sections, %{}, fn section, map ->
      Map.put(map, section.range, section)
    end)
  end

  @doc """
  `sections_in_order/1` takes the `Section`s backing a `LogicalFile` and
  returns them as a list, ordered by the range of logical line numbers they
  represent.
  """
  def sections_in_order(%LogicalFile{sections: sections}) do
    sections
    |> Map.values()
    |> Enum.sort_by(fn %Section{range: range} -> range end)
  end

  @doc """
  `partition_sections/2` accepts a list of `Section`s and a logical
  line number `at_line` representing an insertion point. It  returns a tuple
  `{sections_before, insert_section, sections_after}` by finding the `Section`
  containing `at_line` and partitioning the remaining `Section`s around it.
  """
  def partition_sections(sections, at_line) when is_list(sections) do
    sections
    |> Enum.sort_by(fn section -> section.range end)
    |> Enum.split_while(fn section -> at_line not in section.range end)
    |> then(fn split ->
      case split do
        {_, []} -> {sections, nil, []}
        {before, [target | rest]} -> {before, target, rest}
      end
    end)
  end
end

defimpl String.Chars, for: LogicalFile do
  def to_string(%LogicalFile{} = file) do
    file
    |> LogicalFile.lines()
    |> Enum.join("\n")
  end
end
