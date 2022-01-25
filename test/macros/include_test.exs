defmodule LogicalFile.Macros.IncludeTest do
  use ExUnit.Case
  doctest LogicalFile.Macros.Include

  alias LogicalFile
  alias LogicalFile.Macros.Include

  test "include source" do
    file =
      LogicalFile.read("test/support", "main.source")
      |> Include.apply_macro(expr: ~r/%\((?<file>.*)\)/)

    assert 15 = LogicalFile.size(file)
    assert "alpha" = LogicalFile.line(file, 6)
  end

  test "double include" do
    file = LogicalFile.read(
      "test/support",
      "double_main.source",
      [Include.invocation(expr: ~r/^\s*%\((?<file>.*)\)/)]
    )

    assert 16 = LogicalFile.size(file)
    assert "alpha" = LogicalFile.line(file, 7)
  end

end
