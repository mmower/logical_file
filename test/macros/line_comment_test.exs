defmodule LogicalFile.Macros.LineCommentTest do
  use ExUnit.Case
  doctest LogicalFile.Macros.LineComment

  alias LogicalFile
  alias LogicalFile.Macros.LineComment

  test "transforms comments" do
    map =
      LogicalFile.read("test/support", "commented.source")
      |> LineComment.apply_macro(expr: ~r/^%%/)

    assert "two" = LogicalFile.line(map, 2)
    assert "               " = LogicalFile.line(map, 3)
  end
end
