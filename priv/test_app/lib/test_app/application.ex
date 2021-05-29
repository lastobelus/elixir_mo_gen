defmodule TestApp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {TestApp.Repo, []}
    ]

    opts = [strategy: :one_for_one, name: TestApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
