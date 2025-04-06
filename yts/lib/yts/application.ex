defmodule Yts.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  defp bart_serving() do
    Logger.info("loading bart-large-cnn")
    Nx.global_default_backend(EXLA.Backend)
    {:ok, model_info} = Bumblebee.load_model({:hf, "facebook/bart-large-cnn"})
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, "facebook/bart-large-cnn"})
    {:ok, generation_config} = Bumblebee.load_generation_config({:hf, "facebook/bart-large-cnn"})
    generation_config = Bumblebee.configure(generation_config, max_new_tokens: 250)

    Bumblebee.Text.generation(model_info, tokenizer, generation_config)
  end

  defp whisper_serving() do
    Logger.info("loading whister-tiny")
    {:ok, model_info} = Bumblebee.load_model({:hf, "openai/whisper-tiny"})
    {:ok, featurizer} = Bumblebee.load_featurizer({:hf, "openai/whisper-tiny"})
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, "openai/whisper-tiny"})
    {:ok, generation_config} = Bumblebee.load_generation_config({:hf, "openai/whisper-tiny"})

    Bumblebee.Audio.speech_to_text_whisper(model_info, featurizer, tokenizer, generation_config,
      compile: [batch_size: 4],
      defn_options: [
        compiler: EXLA,
        cache: Path.join(System.tmp_dir!(), "speech_to_text")
      ]
    )
  end

  @impl true
  def start(_type, _args) do
    children = [
      YtsWeb.Telemetry,
      {Nx.Serving, name: Yts.BartServing, serving: bart_serving()},
      {Nx.Serving, name: Yts.WhisperServing, serving: whisper_serving()},
      Yts.Repo,
      {Ecto.Migrator, repos: Application.fetch_env!(:yts, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:yts, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Yts.PubSub},
      # Start a worker by calling: Yts.Worker.start_link(arg)
      # {Yts.Worker, arg},
      # Start to serve requests, typically the last entry
      YtsWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Yts.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    YtsWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") == nil
  end
end
