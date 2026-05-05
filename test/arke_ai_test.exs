defmodule ArkeAiTest do
  use ExUnit.Case
  doctest ArkeAi

  test "greets the world" do
    assert ArkeAi.hello() == :world
  end
end
