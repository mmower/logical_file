defmodule LogicalFile.Section do
  alias __MODULE__

  @moduledoc """
  A `Section` represents lines of text from a backing file that represent
  a range of logical line numbers within a `LogicalFile`.

  ## Fields

    * `source_path` the fully qualified file name of the backing file that
      the `Section` represents.
    * `range` the range of logical line numbers the `Section` represents
    * `lines` a list of the lines in the `Section`
    * `offset` a value that transforms a logical line number to a local
      line number within the backing file.

  In the simple case a `Section` represents the entire contents of a backing
  file. However, a `Section` can be split and moved (for example when another
  `Section` is inserted within its range). Here the `offset` is adjusted to
  allow the conversion of logical line numbers to local line numbers in the
  backing file.
  """

  defstruct source_path: nil,
            range: 0..0,
            lines: [],
            offset: 0

  # Interface

  @doc """
  `new/1` creates a new `Section` representing lines from the specified file.

  `new/4` creates a new `Section` representing the contents of the file specified
  by `source_path` and representing a particular range of logical line numbers
  and their offset
  `new/4` for more information.


  a range of lines with an offset.
  he offset determines how the line numbers in the range are converted into lines in the
  source file. For example if the offset is -5 then line 10 will correspond to
  line 5 of the source file.

  ## Examples
      iex> alias LogicalFile.Section
      iex> section = Section.new("test/support/main.source")
      iex> assert "test/support/main.source" = section.source_path
      iex> assert 11 = Section.size(section)
      iex> assert 1..11 = section.range
      iex> assert 0 = section.offset

      iex> alias LogicalFile.Section
      iex> %Section{source_path: source_path, range: range, lines: lines} =
      ...>  Section.new("foo.source", 1..6, ["one", "two", "three", "four", "five", "six"])
      iex> assert "foo.source" = source_path
      iex> assert 1..6 = range
      iex> assert 6 = Enum.count(lines)

      iex> alias LogicalFile.Section
      iex> %Section{offset: offset} = Section.new("foo.source", 1..2, ["one", "two"], -7)
      iex> assert -7 = offset

      iex> alias LogicalFile.Section
      iex> assert_raise(RuntimeError, fn ->
      ...> %Section{} =
      ...>  Section.new("foo.source", 1..5, ["one", "two", "three", "four"])
      ...> end)
  """
  def new(source_path) do
    with lines = read_lines(source_path),
         line_count = Enum.count(lines) do
      new(source_path, 1..line_count, lines)
    end
  end

  def new(source_path, range, lines, offset \\ 0) do
    if Enum.count(lines) != Range.size(range), do: raise("Range and line count does not match!")

    %Section{source_path: source_path, range: range, lines: lines, offset: offset}
  end

  @doc """
  `line/2` returns a `String` containing the contents of logical line number
  `lno` which is expected to be within the range the `Section` represents.

  ## Examples
      iex> alias LogicalFile.Section
      iex> section = Section.new("test/support/main.source")
      iex> assert "%(include.source)" = Section.line(section, 6)
  """
  def line(%Section{range: lo.._hi, lines: lines}, lno) do
    Enum.at(lines, lno-lo)
  end

  @doc """
  `line_matching/2` takes a `Section` and either a predicate function or a
  regular expression and returns a tuple `{logical_line_no, line}` representing
  the first line from the `Section` that matches.

  ## Examples
      iex> alias LogicalFile.Section
      iex> section = Section.new("test/support/main.source")
      iex> include = ~r/%\((?<file>.*)\)/
      iex> assert {6, "%(include.source)"} = Section.line_matching(section, fn line -> String.length(line) > 5 end)
      iex> assert {6, "%(include.source)"} = Section.line_matching(section, include)
  """
  def line_matching(%Section{range: range, lines: lines}, pred_fn) when is_function(pred_fn) do
    Enum.zip(range, lines)
    |> Enum.find(fn {_lno, line} -> pred_fn.(line) end)
  end

  def line_matching(%Section{range: range, lines: lines}, %Regex{} = expr) do
    Enum.zip(range, lines)
    |> Enum.find(fn {_lno, line} -> Regex.match?(expr, line) end)
  end

  @doc """
  `lines_matching/2` takes a `Section` and either a predicate function or a
  regular expression and returns a list of tuples of the form
  `{logical_lno, line}` for each line that matches.

  ## Examples
      iex> alias LogicalFile.Section
      iex> section = Section.new("test/support/commented.source")
      iex> assert [{3, "%% nothing here"}, {6, "%% or here"}] = Section.lines_matching(section, fn line ->
      ...>  String.starts_with?(line, "%%")
      ...> end)
      iex> assert [{1, "one"}, {2, "two"}, {8, "six"}] = Section.lines_matching(section, fn line -> String.length(line) <4 end)
  """
  def lines_matching(%Section{range: range, lines: lines}, fun) when is_function(fun) do
    Enum.zip(range, lines)
    |> Enum.filter(fn {_lno, line} -> fun.(line) end)
  end

  def lines_matching(%Section{range: range, lines: lines}, %Regex{} = expr) do
    Enum.zip(range, lines)
    |> Enum.filter(fn {_lno, line} -> Regex.match?(expr, line) end)
  end

  @doc """
  `update_line/3` takes a `Section` a logical number number expected to be
  within the `Section` and a function. It replaces that line with the result
  of calling the function with the existing line.

  ## Examples
      iex> alias LogicalFile.Section
      iex> section = Section.new("test/support/main.source")
      ...>  |> Section.update_line(6, fn line -> String.duplicate(" ", String.length(line)) end)
      iex> assert "                 " = Section.line(section, 6)
  """
  def update_line(%Section{range: lo.._hi = range, lines: lines} = section, lno, fun)
      when is_function(fun) do
    if lno not in range, do: raise "Section (#{inspect(range)}) does not contain line: #{lno}"
    %{section | lines: List.update_at(lines, lno - lo, fun)}
  end

  @doc """
  `splittable?/1` takes a `Section` and determines whether it is splittable. In
  general it's not splittable if it contains only one line.

  ## Examples
      iex> alias LogicalFile.Section
      iex> section1 = Section.new("bar.source", 1..1, ["one"])
      iex> section2 = Section.new("foo.source", 1..2, ["one", "two"])
      iex> assert not Section.splittable?(section1)
      iex> assert Section.splittable?(section2)
  """
  def splittable?(%Section{range: lo..lo}), do: false
  def splittable?(%Section{}), do: true

  @doc """
  `split/2` takes a `Section` and a logical line number `at_line` expected to be
  within the `Section` and returns a tuple `{before_section, after_section}`
  derived by splitting the contents of the Section at the specified line.

  The `before_section` contains all lines up to the specified line, the
  `after_section` contains all lines from the specified line to the end of
  the `Section`.

  ## Examples
      iex> alias LogicalFile.Section
      iex> section = Section.new("foo.source", 1..6, ["one", "two", "three", "four", "five", "six"])
      iex> {%Section{} = first, %Section{} = second} = Section.split(section, 4)
      iex> assert "foo.source" = first.source_path
      iex> assert 1..3 = first.range
      iex> assert ["one", "two", "three"] = first.lines
      iex> assert "foo.source" = second.source_path
      iex> assert 4..6 = second.range
      iex> assert ["four", "five", "six"] = second.lines

      iex> alias LogicalFile.Section
      iex> assert_raise(RuntimeError, fn ->
      ...>  section = Section.new("foo.source", 1..4, ["one", "two", "three", "four"])
      ...>  Section.split(section, 0)
      ...> end)

      iex> alias LogicalFile.Section
      iex> section = Section.new("foo.source", 1..3, ["alpha", "beta", "delta"]) |> Section.shift(36)
      iex> {s1, s2} = Section.split(section, 38)
      iex> assert %Section{range: 37..37, offset: -36, lines: ["alpha"]} = s1
      iex> assert %Section{range: 38..39, offset: -36, lines: ["beta", "delta"]} = s2
  """
  def split(%Section{range: lo..lo}), do: raise "Cannot split a section containing one line!"
  def split(%Section{range: lo.._}, lo), do: raise "Cannot set split point on first line!"
  def split(%Section{range: _..hi}, hi), do: raise "Cannot set split point on last line!"
  def split(%Section{source_path: path, range: lo..hi = range, lines: lines, offset: offset}, at_line) do
    if at_line not in range, do: raise("Line specified outside range")

    pre_range = lo..(at_line-1)
    pre_index = lo + offset - 1 # offsets are negative
    pre_amount = Enum.count(pre_range)

    post_range = at_line..hi
    post_index = at_line - 1 + offset
    post_amount = Enum.count(post_range)

    {
      %Section{
        source_path: path,
        range: pre_range,
        offset: offset,
        lines: Enum.slice(lines, pre_index, pre_amount)
      },
      %Section{
        source_path: path,
        range: post_range,
        offset: offset,
        lines: Enum.slice(lines, post_index, post_amount)
      }
    }
  end

  @doc """
  `shift/2` takes a `Section` and a number of lines to offset the section
  `by_lines` and returns a new `Section` containing the same lines with the
  logical line number range and offset shifted appropriately.

  ## Examples
      iex> alias LogicalFile.Section
      iex> section =
      ...>  Section.new("foo.source", 1..4, ["one", "two", "three", "four"])
      ...>  |> Section.shift(10)
      iex> assert 11..14 = section.range
      iex> assert -10 = section.offset
  """
  def shift(%Section{} = section, 0), do: section
  def shift(%Section{range: lo..hi, offset: offset} = section, by_lines) do
    section
    |> set_range((lo + by_lines)..(hi + by_lines))
    |> set_offset(offset - by_lines)
  end

  @doc """
  `first_line_number/1` returns the first logical line number of the specified
  `Section`.
  """
  def first_line_number(%Section{range: lo.._hi}) do
    lo
  end

  @doc """
  `last_line_number/1` returns the last logical line number of the specified
  `Section`.
  """
  def last_line_number(%Section{range: _lo..hi}) do
    hi
  end

  @doc """
  `size/1` returns the number of lines in the specified `Section`.

  ## Examples
      iex> alias LogicalFile.Section
      iex> section = Section.new("foo.source", 1..4, ["one", "two", "three", "four"])
      iex> assert 4 = Section.size(section)
  """
  def size(%Section{lines: lines}) do
    Enum.count(lines)
  end

  @doc """
  `total_size/1` returns the number of lines contained in the given list of
  `Section`s.

  ## Examples
      iex> alias LogicalFile.Section
      iex> section1 = Section.new("foo.source", 1..4, ["one", "two", "three", "four"])
      iex> section2 = Section.new("bar.source", 5..7, ["alpha", "beta", "delta"])
      iex> assert 7 = Section.total_size([section1, section2])
  """
  def total_size(sections) when is_list(sections) do
    Enum.reduce(sections, 0, fn section, acc -> acc + Section.size(section) end)
  end

  @doc """
  `set_range/2` replaces the logical line number range of the specified
  `Section`.
  """
  def set_range(%Section{} = section, new_range) do
    %{section | range: new_range}
  end

  @doc """
  `set_offset/2` replaces the line number offset of the specified `Section`.
  """
  def set_offset(%Section{} = section, new_offset) do
    %{section | offset: new_offset}
  end

  @doc """
  `resolve_line/2` takes a `Section` and a logical line number `line` that is
  expected to be within the range of the `Section` and returns a tuple
  `{file, line}` representing the file backing the `Section` and the
  corresponding local line number within the `Section`

  number
  Maps a line number coming from a source map that may include many sections
  into a line number relative to the section. For example a section may represent
  source included from another file.

  E.g. File 1 contains 20 lines & File 2 contains 10 lines if we insert File 2
  we get a structure like:

  Lines  1..10 => File 1: Lines  1..10
  Lines 11..20 => File 2: Lines  1..10
  Lines 21..30 => File 1: Lines 11..20

  If we ask for line 15 this maps to File 2, line 5. This means file 2 is
  offset from the map by -10. If we ask for line 25 this maps to file 1
  line 15, again offset by -10.

  ## Examples
      iex> alias LogicalFile.Section
      iex> section =
      ...>  Section.new("test/support/main.source")
      ...>  |> Section.set_range(21..30)
      ...>  |> Section.set_offset(-10)
      iex> assert {"test/support/main.source", 15} = Section.resolve_line(section, 25)
  """
  def resolve_line(%Section{source_path: source_path, range: range, offset: offset}, line) do
    if line in range do
      {source_path, line + offset}
    else
      raise "Attempt to resolve logical line #{line} outside section range #{inspect(range)}"
    end
  end

  # Implementation

  defp read_lines(source_path) when is_binary(source_path) do
    source_path
    |> File.read!()
    |> String.split(~r/\R/)
  end

end
