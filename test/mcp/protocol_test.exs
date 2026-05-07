defmodule ArkeAi.Mcp.ProtocolTest do
  use ExUnit.Case, async: true

  alias ArkeAi.Mcp.Protocol

  describe "notifications" do
    test "treats messages with id: nil as notifications" do
      assert {:notification, nil} = Protocol.handle(%{"id" => nil}, nil, [])
    end

    test "treats messages without id as notifications" do
      assert {:notification, nil} = Protocol.handle(%{"method" => "anything"}, nil, [])
    end
  end

  describe "initialize" do
    test "returns capabilities, protocolVersion, and serverInfo" do
      assert {:ok, result} =
               Protocol.handle(%{"id" => 1, "method" => "initialize"}, nil, [])

      assert %{
               "capabilities" => %{"tools" => %{"listChanged" => true}},
               "protocolVersion" => "2025-03-26",
               "serverInfo" => %{"name" => name, "version" => version}
             } = result

      assert is_binary(name)
      assert is_binary(version)
    end

    test "uses opts[:name] and opts[:version] when present" do
      assert {:ok, %{"serverInfo" => %{"name" => "Custom", "version" => "9.9.9"}}} =
               Protocol.handle(%{"id" => 1, "method" => "initialize"}, nil,
                 name: "Custom",
                 version: "9.9.9"
               )
    end

    test "derives name and version from opts[:otp_app] when no explicit values" do
      assert {:ok, %{"serverInfo" => %{"name" => "arke_ai"}}} =
               Protocol.handle(%{"id" => 1, "method" => "initialize"}, nil, otp_app: :arke_ai)
    end

    test "honors opts[:protocol_version]" do
      assert {:ok, %{"protocolVersion" => "1999-01-01"}} =
               Protocol.handle(%{"id" => 1, "method" => "initialize"}, nil,
                 protocol_version: "1999-01-01"
               )
    end
  end

  describe "unknown method" do
    test "returns method-not-found error" do
      assert {:error, -32_601, "method not found"} =
               Protocol.handle(%{"id" => 1, "method" => "wat"}, nil, [])
    end
  end
end
