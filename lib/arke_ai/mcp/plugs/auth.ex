defmodule ArkeAi.Mcp.Plugs.Auth do
  @moduledoc "Plug handling `:local` (IP-restricted, project from header/opts) and `:bearer` (Guardian JWT) auth modes. Sets `:arke_project` on conn assigns."
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    opts = conn.assigns.router_opts

    case opts[:auth] do
      :local -> handle_local(conn, opts)
      :bearer -> handle_bearer(conn)
      _ -> conn |> send_resp(500, "no auth mode configured") |> halt()
    end
  end

  defp handle_local(conn, opts) do
    with true <- is_local?(conn.remote_ip),
         {:ok, project_id} <- resolve_project(conn, opts) do
      assign(conn, :arke_project, project_id)
    else
      false -> conn |> send_resp(403, "Forbidden") |> halt()
      {:error, msg} -> conn |> send_resp(400, msg) |> halt()
    end
  end

  defp handle_bearer(conn) do
    conn
    |> ArkeAi.Mcp.Plugs.GuardianPipeline.call([])
    |> load_project_from_token()
  end

  defp load_project_from_token(%{halted: true} = conn), do: conn

  defp load_project_from_token(conn) do
    member = ArkeAuth.Guardian.get_member(conn)

    conn
    |> assign(:arke_project, member.metadata.project)
    |> assign(:arke_member, member)
  end

  defp resolve_project(conn, opts) do
    case get_req_header(conn, "arke-project-key") do
      [proj | _] -> validate_project(proj)
      [] -> resolve_project_from_opts(opts)
    end
  end

  defp resolve_project_from_opts(opts) do
    case opts[:project] do
      nil -> {:error, "missing arke-project-key header"}
      proj -> validate_project(to_string(proj))
    end
  end

  defp validate_project(proj) do
    case Arke.QueryManager.get_by(project: :arke_system, arke: :arke_project, id: proj) do
      nil -> {:error, "invalid project"}
      unit -> {:ok, unit.id}
    end
  end

  defp is_local?({127, 0, 0, _}), do: true
  defp is_local?({0, 0, 0, 0, 0, 0, 0, 1}), do: true
  defp is_local?(_), do: false
end
