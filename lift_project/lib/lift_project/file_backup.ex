defmodule FileBackup do
  @moduledoc """
  Writes and reads data to an external file.
  """
  
  @spec write(any(), String.t())
  def write(data, filename) do
    {:ok, file} = File.open(filename, [:write])
    binary = :erlang.term_to_binary(data)
    IO.binwrite(file, binary)
    File.close(file)
  end

  @spec read(String.t()) :: {:ok, any()} | {:error, reason}
  def read(filename) do
    case File.read(filename) do
      {:ok, binary} ->
        data = :erlang.binary_to_term(binary)
        {:ok, data}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
