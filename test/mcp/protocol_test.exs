defmodule ArkeAi.Mcp.ProtocolTest do
  use ExUnit.Case, async: true

  alias ArkeAi.Mcp.Protocol

  describe "notifications" do
    test "returns notification when id is missing" do
      assert {:notification, nil} = Protocol.handle(%{"method" => "initialize"}, nil)
    end

    test "returns notification when id is null" do
      assert {:notification, nil} = Protocol.handle(%{"method" => "initialize", "id" => nil}, nil)
    end
  end

  describe "initialize" do
    test "returns protocol version and capabilities" do
      assert {:ok, result} = Protocol.handle(%{"method" => "initialize", "id" => "1"}, nil)
      assert result["protocolVersion"] == "2025-03-26"
      assert result["capabilities"] == %{"tools" => %{}}
      assert result["serverInfo"]["name"] == "arke_ai"
    end

    test "allows protocol version override via opts" do
      assert {:ok, result} = Protocol.handle(%{"method" => "initialize", "id" => "1"}, nil, protocol_version: "2024-01-01")
      assert result["protocolVersion"] == "2024-01-01"
    end
  end

  describe "tools/list" do
    test "returns a list of tools" do
      assert {:ok, %{"tools" => tools}} = Protocol.handle(%{"method" => "tools/list", "id" => "1"}, nil)
      assert is_list(tools)
      assert length(tools) > 0
    end

    test "each tool has required fields" do
      assert {:ok, %{"tools" => tools}} = Protocol.handle(%{"method" => "tools/list", "id" => "1"}, nil)
      Enum.each(tools, fn tool ->
        assert Map.has_key?(tool, "name")
        assert Map.has_key?(tool, "description")
        assert Map.has_key?(tool, "inputSchema")
      end)
    end
  end

  describe "tools/call" do
    test "returns content for known tool" do
      assert {:ok, result} =
               Protocol.handle(
                 %{"method" => "tools/call", "id" => "1", "params" => %{"name" => "test", "arguments" => %{}}},
                 nil
               )

      assert [%{"type" => "text", "text" => _}] = result["content"]
      refute result["isError"]
    end

    test "returns isError for unknown tool" do
      assert {:ok, result} =
               Protocol.handle(
                 %{"method" => "tools/call", "id" => "1", "params" => %{"name" => "unknown", "arguments" => %{}}},
                 nil
               )

      assert result["isError"] == true
      assert [%{"type" => "text"}] = result["content"]
    end
  end

  describe "unknown method" do
    test "returns method not found error" do
      assert {:error, -32601, _message} = Protocol.handle(%{"method" => "unknown/method", "id" => "1"}, nil)
    end
  end
end
