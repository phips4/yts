defmodule Yts.Ai do
  require Logger

  defp join_text_chunks(tasks) do
    tasks
    |> Enum.map(fn {:ok, %{chunks: chunks}} ->
      chunks
      |> Enum.map(& &1.text)
      |> Enum.join(" ")
    end)
    |> Enum.join(" ")
  end

  def speech_to_text(path) do
    {:ok, stat} = Yts.Mp3Stat.parse(path)
    chunk_time = 60

    0..stat.duration//chunk_time
    |> Task.async_stream(
      fn ss ->
        args = ~w(-ac 1 -ar 16k -f f32le -ss #{ss} -t #{chunk_time} -v quiet -)
        {data, 0} = System.cmd("ffmpeg", ["-i", path] ++ args)
        Nx.Serving.batched_run({:local, Yts.WhisperServing}, Nx.from_binary(data, :f32))
      end,
      max_concurrency: 4,
      timeout: :infinity
    )
    |> join_text_chunks()
  end

  def summarize_text(text) do
    Nx.Serving.batched_run({:local, Yts.BartServing}, text)
    |> Enum.map(fn {:results, results} ->
      Enum.map(results, fn %{text: text} -> text end) |> Enum.join(" ")
    end)
  end
end
