defmodule Quiz do
  @questions [
    {"Столица Франции?", "париж"},
    {"2 + 2 * 2 = ?", "6"},
    {"Сколько бит в байте?", "8"},
    {"На какой виртуальной машине работает Elixir?", "beam"},
    {"Самая большая планета Солнечной системы?", "юпитер"}
  ]
  @total length(@questions)

  def start(port) do
    {:ok, listen} = :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true])
    IO.puts("Ждём игроков на порту #{port}, Enter — начать викторину")
    main = self()
    spawn(fn -> accept(listen, main) end)

    spawn(fn ->
      IO.gets("")
      send(main, :start)
    end)

    players = lobby([])
    :gen_tcp.close(listen)
    scores = play(players)
    results(players, scores)
    Enum.each(players, fn {_, socket} ->
      drain(socket)
      :gen_tcp.close(socket)
    end)
  end

  defp accept(listen, main) do
    with {:ok, socket} <- :gen_tcp.accept(listen) do
      :gen_tcp.controlling_process(socket, main)
      spawn(fn -> join(socket, main) end)
      accept(listen, main)
    end
  end

  defp join(socket, main) do
    say(socket, "Как тебя зовут?")
    send(main, {:joined, read(socket), socket})
  end

  defp lobby(players) do
    receive do
      {:joined, name, socket} ->
        players = players ++ [{name, socket}]
        announce(players, "#{name} в игре, игроков: #{length(players)}")
        say(socket, "Ждём, когда ведущий начнёт викторину...")
        lobby(players)

      :start ->
        players
    end
  end

  defp play(players) do
    announce(players, "Викторина начинается!")

    rounds =
      for {{question, answer}, i} <- Enum.with_index(@questions, 1) do
        Enum.each(players, fn {_, socket} -> drain(socket) end)
        announce(players, "Вопрос #{i}/#{@total}: #{question}")

        right =
          players
          |> Enum.map(fn {_, socket} -> Task.async(fn -> check(socket, answer) end) end)
          |> Task.await_many(:infinity)

        announce(players, "Правильный ответ: #{answer}")
        right
      end

    Enum.zip_with(rounds, fn answers -> Enum.count(answers, & &1) end)
  end

  defp results(players, scores) do
    table =
      players
      |> Enum.zip_with(scores, fn {name, _}, score -> {name, score} end)
      |> Enum.sort_by(fn {_, score} -> score end, :desc)
      |> Enum.with_index(1)
      |> Enum.map(fn {{name, score}, place} ->
        "#{place}. #{String.pad_trailing(name, 12)} #{score}/#{@total}  #{round(score * 100 / @total)}%"
      end)

    announce(players, Enum.join(["Итоги:" | table], "\n"))
  end

  defp check(socket, answer) do
    reply = String.downcase(read(socket))
    say(socket, "Ответ принят, ждём остальных...")
    reply == answer
  end

  defp announce(players, text) do
    IO.puts(text)
    Enum.each(players, fn {_, socket} -> say(socket, text) end)
  end

  defp say(socket, text), do: :gen_tcp.send(socket, text <> "\n")

  defp drain(socket) do
    with {:ok, _} <- :gen_tcp.recv(socket, 0, 0), do: drain(socket)
  end

  defp read(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, line} -> String.trim(line)
      _ -> ""
    end
  end
end

Quiz.start(8080)
