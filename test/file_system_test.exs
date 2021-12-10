defmodule SecretsWatcherFileSystemTest do
  use ExUnit.Case, async: true

  test "file event api" do
    tmp_dir = System.cmd("mktemp", ["-d"]) |> elem(0) |> String.trim
    {:ok, pid} = SecretsWatcherFileSystem.start_link(dirs: [tmp_dir])
    SecretsWatcherFileSystem.subscribe(pid)

    :timer.sleep(200)
    File.touch("#{tmp_dir}/a")
    assert_receive {:file_event, ^pid, {_path, _events}}, 5000

    new_subscriber = spawn(fn ->
      SecretsWatcherFileSystem.subscribe(pid)
      :timer.sleep(10000)
    end)
    assert Process.alive?(new_subscriber)
    Process.exit(new_subscriber, :kill)
    refute Process.alive?(new_subscriber)

    :timer.sleep(200)
    File.touch("#{tmp_dir}/b")
    assert_receive {:file_event, ^pid, {_path, _events}}, 5000

    Port.list()
    |> Enum.reject(fn port ->
      :undefined == port |> Port.info |> Access.get(:os_pid)
    end)
    |> Enum.each(&Port.close/1)
    assert_receive {:file_event, ^pid, :stop}, 5000

    File.rm_rf!(tmp_dir)
  end
end
