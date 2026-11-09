defmodule ArkeAi.Mcp.Schema.ParameterToJson do
  @moduledoc "Converts an Arke parameter unit to a JSON Schema fragment (type + constraints + default)."

  alias Arke.Core.Unit

  def convert(%Unit{} = param) do
    schema = base(param)

    if param.data[:multiple] == true do
      {default, items} = Map.pop(schema, "default")
      put_default(%{"type" => "array", "items" => items}, default)
    else
      schema
    end
  end

  defp base(%Unit{arke_id: :string} = param) do
    %{"type" => "string"}
    |> put_min_length(param.data[:min_length])
    |> put_max_length(param.data[:max_length])
    |> put_enum(param.data[:values])
    |> put_default(param.data[:default_string])
  end

  defp base(%Unit{arke_id: :integer} = param) do
    %{"type" => "integer"}
    |> put_minimum(param.data[:min])
    |> put_maximum(param.data[:max])
    |> put_enum(param.data[:values])
    |> put_default(param.data[:default_integer])
  end

  defp base(%Unit{arke_id: :float} = param) do
    %{"type" => "number"}
    |> put_minimum(param.data[:min])
    |> put_maximum(param.data[:max])
    |> put_default(param.data[:default_float])
  end

  defp base(%Unit{arke_id: :boolean} = param),
    do: %{"type" => "boolean"} |> put_default(param.data[:default_boolean])

  defp base(%Unit{arke_id: :date} = param),
    do: %{"type" => "string", "format" => "date"} |> put_default(param.data[:default_date])

  defp base(%Unit{arke_id: :datetime} = param),
    do: %{"type" => "string", "format" => "date-time"} |> put_default(param.data[:default_datetime])

  defp base(%Unit{arke_id: :time} = param),
    do: %{"type" => "string", "format" => "time"} |> put_default(param.data[:default_time])

  defp base(%Unit{arke_id: :dict} = param),
    do: %{"type" => "object"} |> put_default(param.data[:default_dict])

  defp base(%Unit{arke_id: :list} = param),
    do: %{"type" => "array"} |> put_default(param.data[:default_list])

  defp base(%Unit{arke_id: :link}), do: %{"type" => "string"}

  # :dynamic, :binary and custom types: one unknown type must not crash tools/list
  defp base(%Unit{}), do: %{}

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
