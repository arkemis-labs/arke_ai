defmodule ArkeAi.Mcp.NotificationsTest do
  use ExUnit.Case, async: false

  alias ArkeAi.Mcp.Notifications

  describe "subscribe/1 + tools_list_changed/1" do
    test "broadcasts the JSON-RPC notification to subscribers of the project" do
      Notifications.subscribe(:test_project)
      Notifications.tools_list_changed(:test_project)

      assert_receive {:mcp_notification,
                      %{"jsonrpc" => "2.0", "method" => "notifications/tools/list_changed"}}
    end

    test "subscribers of a different project do not receive the notification" do
      Notifications.subscribe(:project_a)
      Notifications.tools_list_changed(:project_b)

      refute_receive {:mcp_notification, _}, 50
    end

    test "fans out to multiple subscribers of the same project" do
      caller = self()

      task1 =
        Task.async(fn ->
          Notifications.subscribe(:fanout)
          send(caller, :ready)
          assert_receive {:mcp_notification, _}, 200
          :received
        end)

      task2 =
        Task.async(fn ->
          Notifications.subscribe(:fanout)
          send(caller, :ready)
          assert_receive {:mcp_notification, _}, 200
          :received
        end)

      assert_receive :ready
      assert_receive :ready

      Notifications.tools_list_changed(:fanout)

      assert Task.await(task1) == :received
      assert Task.await(task2) == :received
    end
  end
end
