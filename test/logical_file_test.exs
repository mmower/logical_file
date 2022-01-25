defmodule LogicalFileTest do
  use ExUnit.Case
  doctest LogicalFile

  alias LogicalFile.Section
  alias LogicalFile.Macros.{Include, LineComment}

  test "processes include macro after reading file" do
    file = LogicalFile.read("test/support", "main.source", [Include.invocation(expr: ~r/^\s*%\((?<file>.*)\)/)])
    assert 15 = LogicalFile.size(file)
  end

  test "partitions sections" do
    section1 = %Section{range: 1..10}
    section2 = %Section{range: 11..20}
    section3 = %Section{range: 21..30}
    sections = [section1, section2, section3]
    assert {[], ^section1, [^section2, ^section3]} = LogicalFile.partition_sections(sections, 5)
    assert {[^section1], ^section2, [^section3]} = LogicalFile.partition_sections(sections, 11)
    assert {[^section1, ^section2], ^section3, []} = LogicalFile.partition_sections(sections, 29)
    assert {[^section1, ^section2, ^section3], nil, []} = LogicalFile.partition_sections(sections, 31)
  end

  test "reads and processes macros" do
    assert "one\n" <>
             "two\n" <>
             "three\n" <>
             "four\n" <>
             "five\n" <>
             "alpha\n" <>
             "beta\n" <>
             "delta\n" <>
             "gamma\n" <>
             "                 \n" <>
             "six\n" <>
             "seven\n" <>
             "eight\n" <>
             "nine\n" <>
             "     " =
             LogicalFile.read("test/support", "main.source", [
               Include.invocation(expr: ~r/^\s*%\((?<file>.*)\)/),
               LineComment.invocation(expr: ~r/^\s*%%/)
             ])
             |> to_string()
  end

  test "insert into a single line" do
    file = LogicalFile.read("test/support", "double_include.source", [
      Include.invocation(expr: ~r/^\s*%\((?<file>.*)\)/)
    ])

    assert 5 = LogicalFile.size(file)
  end

  test "resolves lines" do
    source = LogicalFile.read("test/support", "main.source", [
      Include.invocation(expr: ~r/^\s*%\((?<file>.*)\)/),
      LineComment.invocation(expr: ~r/^\s*%%/)
    ])

    assert {"test/support/main.source", 1} = LogicalFile.resolve_line(source, 1)
    assert {"test/support/include.source", 2} = LogicalFile.resolve_line(source, 7)
  end

end
