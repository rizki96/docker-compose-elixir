defmodule DockerCompose do
  @moduledoc """
  Docker Compose CLI

  Uses `docker-compose` executable, it must be installed and working.
  """

  @type exit_code :: non_neg_integer
  @type output :: Collectable.t()

  @doc """
  docker-compose up

  The command is executed in detached mode, result is returned after the whole command finishes,
  which might take a while if the images need to be pulled.

  ## Options
    - `always_yes: true` - answer "yes" to all interactive questions
    - `compose_path: path` - path to the compose if not in the standard location
    - `project_name: name` - compose project name
    - `force_recreate: true` - if true all specified services are forcefully recreated
    - `remove_orphans: true` - if true orphaned containers are removed
    - `service: name` - name of the service that should be started, can be specified multiple times
      to start multiple services. If it's not specified at all then all services are started.
  """
  @spec up(Keyword.t()) :: {:ok, output} | {:error, exit_code, output}
  def up(opts) do
    args =
      [
        compose_opts(opts),
        "up",
        up_opts(opts),
        ["-d", "--no-color" | service_opts(opts)]
      ]
      |> List.flatten()

    args
    |> execute(opts)
    |> result()
  end

  @doc """
  docker-compose down

  ## Options
    - `always_yes: true` - answer "yes" to all interactive questions
    - `compose_path: path` - path to the compose if not in the standard location
    - `project_name: name` - compose project name
    - `remove_orphans: true` - if true orphaned containers are removed

  ## Result

  The function returns either `{:ok, summary}` if the request is successful or `{:error, exit_code,
  summary}`. The exit code is the exit code of the docker-compose process that failed.

  Summary is a map with
    - `stopped_containers` - which containers were stopped
    - `removed_containers` - which containers were removed
    - `removed_networks` - which networks were removed
    - `removed_orphan_containers` - which containers were removed if `remove_orphans: true` is
      specified
  """
  @spec down(Keyword.t()) :: {:ok, output} | {:error, exit_code, output}
  def down(opts) do
    args =
      [
        compose_opts(opts),
        "down",
        down_opts(opts)
      ]
      |> List.flatten()

    args
    |> execute(opts)
    |> result()
  end

  # OPTS
  # - service - optional, by default all
  @doc """
  docker-compose restart

  ## Options
    - `always_yes: true` - answer "yes" to all interactive questions
    - `compose_path: path` - path to the compose if not in the standard location
    - `project_name: name` - compose project name
    - `service: name` - name of the service to be restarted, can be specified multiple times to
      restart multiple services at once. If not specified at all then all services are restarted.
  """
  @spec restart(Keyword.t()) :: {:ok, output} | {:error, exit_code, output}
  def restart(opts) do
    args =
      [
        compose_opts(opts),
        "restart",
        service_opts(opts)
      ]
      |> List.flatten()

    args
    |> execute(opts)
    |> result()
  end

  @doc """
  docker-compose stop

  ## Options
    - `always_yes: true` - answer "yes" to all interactive questions
    - `compose_path: path` - path to the compose if not in the standard location
    - `project_name: name` - compose project name
    - `service: name` - name of the service to be stopped, can be specified multiple times to stop
      multiple services at once. If not specified at all then all services are stopped.
  """
  @spec stop(Keyword.t()) :: {:ok, output} | {:error, exit_code, output}
  def stop(opts) do
    args =
      [
        compose_opts(opts),
        "stop",
        service_opts(opts)
      ]
      |> List.flatten()

    args
    |> execute(opts)
    |> result()
  end

  @doc """
  docker-compose start

  Note this can only be used to start previously created and stopped services. If you want to create
  and start the services use `up/1`.

  ## Options
    - `always_yes: true` - answer "yes" to all interactive questions
    - `compose_path: path` - path to the compose if not in the standard location
    - `project_name: name` - compose project name
    - `service: name` - name of the service to be started, can be specified multiple times to start
      multiple services at once. If not specified at all then all services are started.
  """
  @spec start(Keyword.t()) :: {:ok, output} | {:error, exit_code, output}
  def start(opts) do
    args =
      [
        compose_opts(opts),
        "start",
        service_opts(opts)
      ]
      |> List.flatten()

    args
    |> execute(opts)
    |> result()
  end

  defp execute(args, opts) do
    System.cmd(get_executable(), wrapper_opts(opts) ++ ["--ansi", "never" | args], [
      {:stderr_to_stdout, true} | cmd_opts(opts)
    ])
  end

  defp get_executable do
    case :os.type() do
      {:win32, _} -> "docker-compose.exe"
      _ -> Path.join(:code.priv_dir(:docker_compose), "docker-compose")
    end
  end

  defp wrapper_opts([{:always_yes, true} | rest]) do
    ["--always-yes" | wrapper_opts(rest)]
  end

  defp wrapper_opts([_ | rest]), do: wrapper_opts(rest)
  defp wrapper_opts([]), do: []

  defp compose_opts([{:compose_path, path} | rest]) do
    ["-f", Path.basename(path) | compose_opts(rest)]
  end

  defp compose_opts([{:project_name, name} | rest]) do
    ["-p", name | compose_opts(rest)]
  end

  defp compose_opts([_ | rest]), do: compose_opts(rest)
  defp compose_opts([]), do: []

  defp up_opts(opts) do
    opts
    |> Keyword.take([:force_recreate, :remove_orphans])
    |> command_opts()
  end

  defp down_opts(opts) do
    opts
    |> Keyword.take([:remove_orphans])
    |> command_opts()
  end

  defp command_opts([{:force_recreate, true} | rest]),
    do: ["--force-recreate" | command_opts(rest)]

  defp command_opts([{:remove_orphans, true} | rest]),
    do: ["--remove-orphans" | command_opts(rest)]

  defp command_opts([_ | rest]), do: command_opts(rest)
  defp command_opts([]), do: []

  defp service_opts([{:service, name} | rest]), do: [name | service_opts(rest)]
  defp service_opts([_ | rest]), do: service_opts(rest)
  defp service_opts([]), do: []

  defp cmd_opts([{:compose_path, path} | rest]) do
    [{:cd, Path.dirname(path)} | cmd_opts(rest)]
  end

  defp cmd_opts([{:into, _collectable} = into | rest]) do
    [into | cmd_opts(rest)]
  end

  defp cmd_opts([_ | rest]), do: cmd_opts(rest)
  defp cmd_opts([]), do: []

  defp result({output, exit_code}) do
    if exit_code == 0 do
      {:ok, output}
    else
      {:error, exit_code, output}
    end
  end
end
