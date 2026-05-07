defmodule ArkeAi.Mcp.PermissionTest do
  use ExUnit.Case, async: true

  alias ArkeAi.Mcp.Permission

  describe "apply_to_query/3" do
    test "is a no-op when permission is nil" do
      assert Permission.apply_to_query(:some_query, nil, nil) == :some_query
    end

    test "is a no-op when permission has no filter and no child_only" do
      perm = %{filter: nil, child_only: false}
      assert Permission.apply_to_query(:some_query, perm, nil) == :some_query
    end
  end
end
