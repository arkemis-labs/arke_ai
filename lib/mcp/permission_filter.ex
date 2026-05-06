defmodule ArkeAi.Mcp.PermissionFilter do
  @moduledoc """
  Parses and applies Arke permission filter strings.

  TODO: this is a copy of `ArkeServer.Utils.QueryFilters` with `conn` replaced
  by `project`. The filter DSL parser belongs in `arke` or `arke_auth` as a
  shared util. Extract upstream and drop this module once that lands.

  Filter syntax: `eq(field,value)`, `and(...)`, `or(...)`, `not(...)`, plus
  operator nodes (`eq`, `contains`, `lte`, `gt`, `in`, `isnull`, ...).
  """

  alias Arke.QueryManager
  alias Arke.Core.Query.{Filter, BaseFilter}
  alias Arke.Boundary.ParameterManager
  alias Arke.Utils.ErrorGenerator, as: Error

  def apply_query_filters(query, {logic, negate, filters}) when is_list(filters) do
    apply_filter(query, logic, negate, filters)
  end

  def apply_query_filters(query, _filters), do: query

  def apply_member_child_only(query, member, true) when not is_nil(member),
    do: QueryManager.link(query, member, depth: 10)

  def apply_member_child_only(query, _, _), do: query

  defp apply_filter(query, :and, negate, filters), do: QueryManager.and_(query, negate, filters)
  defp apply_filter(query, :or, negate, filters), do: QueryManager.or_(query, negate, filters)

  def parse(_project, nil), do: {:ok, nil}

  def parse(project, filter_string) when is_binary(filter_string) do
    case parse_node(project, String.trim(filter_string)) do
      {:ok, %Filter{logic: logic, negate: negate, base_filters: filters}} ->
        {:ok, {logic, negate, filters}}

      {:ok, %BaseFilter{} = bf} ->
        {:ok, {:and, false, [bf]}}

      {:error, _} = error ->
        error
    end
  end

  defp parse_node(project, "and(" <> _ = str) do
    with {:ok, inner} <- extract_inner(str), do: parse_logical_node(project, inner, :and)
  end

  defp parse_node(project, "or(" <> _ = str) do
    with {:ok, inner} <- extract_inner(str), do: parse_logical_node(project, inner, :or)
  end

  defp parse_node(project, "not(" <> _ = str) do
    with {:ok, inner} <- extract_inner(str) do
      case parse_node(project, inner) do
        {:ok, %Filter{} = filter} -> {:ok, %Filter{filter | negate: true}}
        {:ok, %BaseFilter{} = bf} -> {:ok, %BaseFilter{bf | negate: true}}
        error -> error
      end
    end
  end

  defp parse_node(project, str) do
    case get_operator(str) do
      {:ok, operator} ->
        with {:ok, inner} <- extract_inner(str),
             do: format_parameter_and_value(project, inner, operator)

      {:error, _} = error ->
        error
    end
  end

  defp parse_logical_node(project, inner, logic) do
    parts = split_top_level(inner)
    results = Enum.map(parts, fn part -> parse_node(project, String.trim(part)) end)
    errors = Enum.filter(results, &match?({:error, _}, &1))

    if errors != [] do
      {:error, Enum.flat_map(errors, fn {:error, msg} -> List.wrap(msg) end)}
    else
      filters = Enum.map(results, fn {:ok, filter} -> filter end)
      {:ok, %Filter{logic: logic, negate: false, base_filters: filters}}
    end
  end

  defp extract_inner(str) do
    case :binary.match(str, "(") do
      {pos, 1} ->
        if String.ends_with?(str, ")") do
          {:ok, binary_part(str, pos + 1, byte_size(str) - pos - 2)}
        else
          Error.create(:filter, "unbalanced parentheses in `#{str}`")
        end

      :nomatch ->
        {:ok, str}
    end
  end

  defp split_top_level(str) do
    {parts, current, _depth} =
      str
      |> String.to_charlist()
      |> Enum.reduce({[], [], 0}, &process_char/2)

    parts
    |> add_last_part(current)
    |> Enum.reject(&(&1 == ""))
  end

  defp process_char(char, {parts, current, depth}) do
    case char do
      ?( ->
        {parts, [char | current], depth + 1}

      ?) ->
        {parts, [char | current], depth - 1}

      ?, when depth == 0 ->
        part = current |> Enum.reverse() |> List.to_string()
        {[part | parts], [], depth}

      _ ->
        {parts, [char | current], depth}
    end
  end

  defp add_last_part(parts, current) do
    last = current |> Enum.reverse() |> List.to_string()
    [last | parts] |> Enum.reverse()
  end

  defp format_parameter_and_value(project, data, :isnull),
    do: get_condition(project, data, :isnull, nil)

  defp format_parameter_and_value(project, data, operator) do
    case String.split(data, ",", parts: 2) do
      [parameter_id, value] -> get_condition(project, parameter_id, operator, value)
      _ -> Error.create(:filter, "invalid value. Use `isnull()` operator to check null values")
    end
  end

  defp get_condition(project, parameter_id, operator, value) do
    {parameter_id, path_ids} =
      parameter_id
      |> String.split(".")
      |> List.pop_at(-1)

    with {:ok, parameter} <- fetch_parameter(parameter_id, project),
         {:ok, path} <- get_path_parameters(path_ids, project) do
      {:ok,
       QueryManager.condition(parameter, operator, parse_value(value, operator), false, path)}
    end
  end

  defp get_path_parameters(path_ids, project) do
    Enum.reduce_while(path_ids, {:ok, []}, fn path_id, {:ok, acc} ->
      case fetch_parameter(path_id, project) do
        {:ok, parameter} -> {:cont, {:ok, [parameter | acc]}}
        {:error, msg} -> {:halt, {:error, msg}}
      end
    end)
    |> case do
      {:ok, path} -> {:ok, Enum.reverse(path)}
      error -> error
    end
  end

  defp fetch_parameter(parameter_id, project) do
    case ParameterManager.get(parameter_id, project) do
      {:error, msg} -> {:error, msg}
      nil -> {:error, "parameter `#{parameter_id}` not found"}
      parameter -> {:ok, parameter}
    end
  end

  defp parse_value(val, :in),
    do: String.replace(val, ~r'[\(\])]', "") |> String.split(",")

  defp parse_value(v, _operator), do: v

  defp get_operator("eq(" <> _), do: {:ok, :eq}
  defp get_operator("contains(" <> _), do: {:ok, :contains}
  defp get_operator("icontains(" <> _), do: {:ok, :icontains}
  defp get_operator("startswith(" <> _), do: {:ok, :startswith}
  defp get_operator("istartswith(" <> _), do: {:ok, :istartswith}
  defp get_operator("endswith(" <> _), do: {:ok, :endswith}
  defp get_operator("iendswith(" <> _), do: {:ok, :iendswith}
  defp get_operator("lte(" <> _), do: {:ok, :lte}
  defp get_operator("lt(" <> _), do: {:ok, :lt}
  defp get_operator("gt(" <> _), do: {:ok, :gt}
  defp get_operator("gte(" <> _), do: {:ok, :gte}
  defp get_operator("in(" <> _), do: {:ok, :in}
  defp get_operator("isnull(" <> _), do: {:ok, :isnull}

  defp get_operator(invalid),
    do: Error.create(:filter, "filter `#{invalid}` not available")
end
