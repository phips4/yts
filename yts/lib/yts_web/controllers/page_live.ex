defmodule YtsWeb.PageLive do
  use Phoenix.LiveView
  use YtsWeb, :html
  embed_templates "pages/*"

  @impl true
  def mount(_, _, socket) do
    {:ok,
     socket
     |> assign(:url, "")
     |> assign(:stage, -1)
     |> assign(:dl, %Phoenix.LiveView.AsyncResult{})
     |> assign(:form, to_form(%{}))
     |> assign(:error, nil)}
  end

  @impl true
  def handle_event("submit", %{"url" => url}, socket) do
    parent = self()

    {:noreply,
     socket
     |> assign(:url, url)
     |> assign(:dl, nil)
     |> assign_async(:dl, fn ->
       options = [
         "extract-audio",
         "restrict-filenames",
         "windows-filenames",
         "audio-format": "mp3",
         paths: "dl"
       ]

       send(parent, %{stage: 0})
       {:ok, file} = Exyt.download(url, options)
       file = String.replace_trailing(file, ".webm", ".mp3")

       send(parent, %{stage: 1})
       text = Yts.Ai.speech_to_text(file)

       send(parent, %{stage: 2})
       summary = Yts.Ai.summarize_text(text)

       send(parent, %{stage: 3})
       {:ok, %{dl: summary}}
     end)}
  end

  @impl true
  def handle_event("validate", %{"_target" => ["url"], "url" => url}, socket) do
    if String.starts_with?(url, "https://www.youtube.com/watch?v=") or
         String.starts_with?(url, "https://www.youtube.com/shorts/") do
      {:noreply, socket |> assign(url: url, error: nil)}
    else
      {:noreply, socket |> assign(url: url, error: "Invalid YouTube URL")}
    end
  end

  def extract_yt_id(url) when is_bitstring(url) do
    if String.contains?(url, "watch?v=") do
      String.split(url, "watch?v=") |> Enum.at(1)
    else
      String.split(url, "/shorts/") |> Enum.at(1)
    end
  end

  @impl true
  def handle_info(%{stage: new_stage}, socket) do
    new_socket =
      socket
      |> assign(stage: new_stage)

    {:noreply, new_socket}
  end
end
