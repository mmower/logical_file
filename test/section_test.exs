defmodule LogicalFile.SectionTest do
  use ExUnit.Case
  doctest LogicalFile.Section
  alias LogicalFile.Section

  test "Cannot create empty Section" do
    assert_raise(RuntimeError, fn ->
      Section.new("path", 29..29, [], 0)
    end)
  end
end
