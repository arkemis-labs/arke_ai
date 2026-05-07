defmodule ArkeAi.Mcp.Tools.RegistryTest do
  use ExUnit.Case, async: true

  # These tests cover the routing layer in isolation:
  # tool name resolution against a config, without exercising Arke ETS or QueryManager.

  alias ArkeAi.Mcp.Tools.{Arke, Group, System}

  describe "tool name resolution shape" do
    test "Arke.resolve maps standard ops to their tool names" do
      ops = [:list, :get, :search, :create, :update, :delete]

      for op <- ops do
        assert Arke.resolve(:car, ops, "#{op}_car") == op
      end
    end

    test "Arke.resolve returns nil on unknown name" do
      assert Arke.resolve(:car, [:list], "make_coffee") == nil
    end

    test "Group.resolve maps regular ops, special ops, and association ops" do
      ops = [:list, :get, :search, :list_arkes, :get_schema, :add_arke, :remove_arke]
      assert Group.resolve(:vehicle, ops, "list_vehicle") == :list
      assert Group.resolve(:vehicle, ops, "list_arkes_vehicle") == :list_arkes
      assert Group.resolve(:vehicle, ops, "add_arke_to_vehicle") == :add_arke
      assert Group.resolve(:vehicle, ops, "remove_arke_from_vehicle") == :remove_arke
    end

    test "System.resolve handles plural list, association irregulars, and parameter type expansion" do
      assert System.resolve(:arke, [:list], "list_arkes") == :list
      assert System.resolve(:parameter, [:list], "list_parameters") == :list
      assert System.resolve(:group, [:list], "list_groups") == :list

      assert System.resolve(:arke, [:add_parameter], "add_parameter_to_arke") == :add_parameter
      assert System.resolve(:arke, [:remove_parameter], "remove_parameter_from_arke") == :remove_parameter

      assert System.resolve(:parameter, [:create], "create_string_parameter") == {:create, :string}
      assert System.resolve(:parameter, [:create], "create_integer_parameter") == {:create, :integer}
      assert System.resolve(:parameter, [:update], "update_link_parameter") == {:update, :link}
    end
  end
end
