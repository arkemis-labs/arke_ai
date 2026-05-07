defmodule ArkeAi.Mcp.Schema.ParameterToJson do
  alias Arke.Core.Unit

  def convert(%Unit{arke_id: :string} = param) do
    %{"type" => "string"}
    |> put_min_length(param.data[:min_length])
    |> put_max_length(param.data[:max_length])
    |> put_enum(param.data[:values])
    |> put_default(param.data[:default_string])
  end

  def convert(%Unit{arke_id: :integer} = param) do
    %{"type" => "integer"}
    |> put_minimum(param.data[:min])
    |> put_maximum(param.data[:max])
    |> put_enum(param.data[:values])
    |> put_default(param.data[:default_integer])
  end

  def convert(%Unit{arke_id: :float} = param) do
    %{"type" => "number"}
    |> put_minimum(param.data[:min])
    |> put_maximum(param.data[:max])
    |> put_default(param.data[:default_float])
  end

  def convert(%Unit{arke_id: :boolean} = param),
    do: %{"type" => "boolean"} |> put_default(param.data[:default_boolean])

  def convert(%Unit{arke_id: :date} = param),
    do: %{"type" => "string", "format" => "date"} |> put_default(param.data[:default_date])

  def convert(%Unit{arke_id: :datetime} = param),
    do: %{"type" => "string", "format" => "date-time"} |> put_default(param.data[:default_datetime])

  def convert(%Unit{arke_id: :time} = param),
    do: %{"type" => "string", "format" => "time"} |> put_default(param.data[:default_time])

  def convert(%Unit{arke_id: :dict} = param),
    do: %{"type" => "object"} |> put_default(param.data[:default_dict])

  def convert(%Unit{arke_id: :list} = param),
    do: %{"type" => "array"} |> put_default(param.data[:default_list])

  def convert(%Unit{arke_id: :link} = param) do
    if param.data[:multiple] == true do
      %{"type" => "array", "items" => %{"type" => "string"}}
    else
      %{"type" => "string"}
    end
  end

  defp put_min_length(schema, nil), do: schema
  defp put_min_length(schema, val), do: Map.put(schema, "minLength", val)

  defp put_max_length(schema, nil), do: schema
  defp put_max_length(schema, val), do: Map.put(schema, "maxLength", val)

  defp put_minimum(schema, nil), do: schema
  defp put_minimum(schema, val), do: Map.put(schema, "minimum", val)

  defp put_maximum(schema, nil), do: schema
  defp put_maximum(schema, val), do: Map.put(schema, "maximum", val)

  defp put_enum(schema, nil), do: schema
  defp put_enum(schema, []), do: schema
  defp put_enum(schema, values), do: Map.put(schema, "enum", Enum.map(values, & &1.value))

  defp put_default(schema, nil), do: schema
  defp put_default(schema, val), do: Map.put(schema, "default", val)
end
