defmodule ArkeAi.Mcp.Permission do
  @moduledoc "Thin wrapper over `ArkeAuth.Utils.Permission`."

  alias ArkeAuth.Utils.Permission, as: ArkeAuthPermission
  alias ArkeAi.Mcp.PermissionFilter

  @op_to_flag %{
    list: :get,
    get: :get,
    search: :get,
    list_arkes: :get,
    get_schema: :get,
    create: :post,
    update: :put,
    delete: :delete,
    add_parameter: :put,
    remove_parameter: :put,
    add_arke: :put,
    remove_arke: :put
  }

  @doc """
  Returns `{:ok, permission_map}` if the op is allowed, `{:error, :forbidden}` otherwise.
  Public is tried first; member fills in if public denies.
  """
  def check(arke_id, op, project, member) do
    flag = flag_for(op)

    with {:ok, perm} <- find_permitting(arke_id, project, member, flag) do
      {:ok, perm |> parse_filter(project, member) |> Map.put_new(:child_only, false)}
    end
  end

  @doc "Apply a permission's filter and child_only constraints to a query. No-op when permission is nil."
  def apply_to_query(query, nil, _member), do: query

  def apply_to_query(query, %{filter: filter, child_only: child_only}, member) do
    query
    |> PermissionFilter.apply_query_filters(filter)
    |> PermissionFilter.apply_member_child_only(member, child_only)
  end

  defp find_permitting(arke_id, project, member, flag) do
    with {:ok, perm} <- ArkeAuthPermission.get_public_permission(arke_id, project),
         true <- Map.get(perm, flag, false) do
      {:ok, perm}
    else
      _ -> member_permitting(arke_id, project, member, flag)
    end
  end

  defp member_permitting(_arke_id, _project, nil, _flag), do: {:error, :forbidden}

  defp member_permitting(arke_id, project, member, flag) do
    with {:ok, perm} <- ArkeAuthPermission.get_member_permission(member, arke_id, project),
         true <- Map.get(perm, flag, false) do
      {:ok, perm}
    else
      _ -> {:error, :forbidden}
    end
  end

  defp parse_filter(perm, project, member) do
    raw = Map.get(perm, :filter)
    member_id = member && member.id
    substituted = substitute_member(raw, member_id)

    parsed =
      case PermissionFilter.parse(project, substituted) do
        {:ok, parsed} -> parsed
        _ -> nil
      end

    Map.put(perm, :filter, parsed)
  end

  defp substitute_member(filter, member_id) when is_binary(filter) and not is_nil(member_id),
    do: String.replace(filter, "{{arke_member}}", to_string(member_id))

  defp substitute_member(filter, _), do: filter

  defp flag_for({op, _type}), do: Map.get(@op_to_flag, op)
  defp flag_for(op), do: Map.get(@op_to_flag, op)
end
