defmodule PolyjuiceTest do
  use ExUnit.Case
  doctest Polyjuice

  test "greets the world" do
    assert Polyjuice.hello() == :world
  end
end
