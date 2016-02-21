defmodule ParallelStream.Filter do
  alias ParallelStream.FilterExecutor
  alias ParallelStream.Workers
  alias ParallelStream.Producer

  @moduledoc ~S"""
  The filter iterator implementation
  """

  defmodule Consumer do
    @moduledoc ~S"""
    The filter consumer - filters according to direction passed
    """

    def build!(stream, direction) do
      stream |> Stream.transform(0, fn items, acc ->
        filtered = items |> Enum.reduce([], fn { relay, index }, list ->
          relay |> send(:next)
          receive do
            { ^relay, { ^index, accepted, item } } ->
              case !!accepted do
                ^direction -> list ++ [item]
                _ -> list
              end
          end
        end)

        { filtered, acc + 1 }
      end)
    end
  end

  @doc """
  Creates a stream that will apply the given function on enumeration in
  parallel and only pass the values for which the function returns truthy
  downstream.

  ## Options

  These are the options:

    * `:num_pipes`   – The number of parallel operations to run when running the stream.

  ## Examples

  Map and filter the even numbers:

      iex> parallel_stream = 1..5 |> ParallelStream.filter(fn i -> i |> rem(2) == 0 end)
      iex> parallel_stream |> Enum.to_list
      [2,4]
  """
  def filter(stream, mapper, options \\ []) do
    pipes = options
            |> Keyword.get(:num_pipes)
            |> Workers.build!(mapper, FilterExecutor)

    stream |> Producer.build!(pipes) 
           |> Consumer.build!(true)
  end

  @doc """
  Creates a stream that will apply the given function on enumeration in
  parallel and only pass the values for which the function returns falsy
  downstream.

  ## Options

  These are the options:

    * `:num_pipes`   – The number of parallel operations to run when running the stream.

  ## Examples

  Map and reject the even numbers:

      iex> parallel_stream = 1..5 |> ParallelStream.reject(fn i -> i |> rem(2) == 0 end)
      iex> parallel_stream |> Enum.to_list
      [1,3,5]
  """
  def reject(stream, mapper, options \\ []) do
    pipes = options
            |> Keyword.get(:num_pipes)
            |> Workers.build!(mapper, FilterExecutor)

    stream |> Producer.build!(pipes) 
           |> Consumer.build!(false)
  end


end
