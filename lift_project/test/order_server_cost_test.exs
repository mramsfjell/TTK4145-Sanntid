defmodule OrderServer.CostTest do
  use ExUnit.Case, async: true
  doctest OrderServer.Cost

  test "Path length handles empty order list" do
    state = {1, :up}
    orders = []
    assert OrderServer.Cost.path_length(orders, state, Order.new(1, :cab)) == 0

    assert OrderServer.Cost.path_length(orders, state, Order.new(1, :hall_up)) ==
             0

    assert OrderServer.Cost.path_length(orders, state, Order.new(2, :cab)) == 1

    assert OrderServer.Cost.path_length(orders, state, Order.new(3, :hall_down)) ==
             2

    assert OrderServer.Cost.path_length(orders, state, Order.new(0, :hall_up)) ==
             1
  end

  test "Path length with one order in same direction" do
    state = {1, :up}
    orders = [Order.new(0, :hall_up)]

    assert OrderServer.Cost.path_length(orders, state, Order.new(0, :hall_up)) ==
             1

    assert OrderServer.Cost.path_length(orders, state, Order.new(1, :hall_up)) ==
             0

    assert OrderServer.Cost.path_length(orders, state, Order.new(2, :hall_up)) ==
             1

    assert OrderServer.Cost.path_length(orders, state, Order.new(3, :hall_up)) ==
             2
  end

  test "Path length with one order in oposite direction" do
    state = {1, :down}
    orders = [Order.new(1, :hall_up)]

    assert OrderServer.Cost.path_length(orders, state, Order.new(0, :hall_up)) ==
             1

    assert OrderServer.Cost.path_length(orders, state, Order.new(1, :hall_up)) ==
             0

    assert OrderServer.Cost.path_length(orders, state, Order.new(2, :hall_up)) ==
             1

    assert OrderServer.Cost.path_length(orders, state, Order.new(3, :cab)) == 2
  end

  test "Path length multiple orders" do
    state = {1, :down}

    orders = [
      Order.new(0, :hall_up),
      Order.new(1, :cab),
      Order.new(2, :hall_down),
      Order.new(3, :cab)
    ]

    assert OrderServer.Cost.path_length(orders, state, Order.new(0, :hall_up)) ==
             1

    assert OrderServer.Cost.path_length(orders, state, Order.new(1, :hall_up)) ==
             2

    assert OrderServer.Cost.path_length(orders, state, Order.new(2, :hall_up)) ==
             3

    assert OrderServer.Cost.path_length(orders, state, Order.new(2, :cab)) == 3

    assert OrderServer.Cost.path_length(orders, state, Order.new(2, :hall_down)) ==
             5
  end

  test "Path finding empty order list" do
    assert OrderServer.Cost.next_order([], 1, :up) == nil
  end

  test "Path finding one order" do
    order = Order.new(1, :cab)
    assert OrderServer.Cost.next_order([order], 1, :up) == order

    order = Order.new(3, :hall_down)
    assert OrderServer.Cost.next_order([order], 1, :up) == order

    order = Order.new(0, :hall_up)
    assert OrderServer.Cost.next_order([order], 1, :up) == order
  end

  test "Path finding multiple orders" do
    orders = [
      Order.new(0, :hall_up),
      Order.new(1, :cab),
      Order.new(2, :hall_down),
      Order.new(3, :cab)
    ]

    assert OrderServer.Cost.next_order(orders, 1, :up) ==
             Enum.fetch!(orders, 1)

    assert OrderServer.Cost.next_order(orders, 1, :down) ==
             Enum.fetch!(orders, 1)

    assert OrderServer.Cost.next_order(orders, 2, :up) ==
             Enum.fetch!(orders, 3)

    assert OrderServer.Cost.next_order(orders, 2, :down) ==
             Enum.fetch!(orders, 2)

    assert OrderServer.Cost.next_order(orders, 0, :up) ==
             Enum.fetch!(orders, 0)
  end
end
