defmodule Conform.Utils do
  @moduledoc false

  import IO.ANSI, only: [green: 0, yellow: 0, red: 0]

  @doc "Print an debugging message"
  def debug(message), do: log("==> #{message}")
  @doc "Print an informational message"
  def info(message),  do: log("==> #{message}", green)
  @doc "Print a warning message"
  def warn(message),  do: log("==> #{message}", yellow)
  @doc "Print a notice message"
  def notice(message), do: log("#{message}", yellow)
  @doc "Print an error message"
  def error(message), do: log("==> #{message}", red)

  # Prints a message to standard output, optionally colorized.
  defp log(message, color \\ nil) do
    case color do
      nil -> IO.puts message
      _   -> IO.puts colorize(message, color)
    end
  end
  # Colorizes a message using ANSI escapes
  defp colorize(message, color), do: color <> message <> IO.ANSI.reset


  @doc """
  Recursively merges two keyword lists. Values themselves are also merged (depending on type),
  such that the resulting keyword list is a true merge of the second keyword list over the first.

  ## Examples

      iex> old = [one: [one_sub: [a: 1, b: 2]], two: {1, "foo", :bar}, three: 'just a charlist', four: [1, 2, 3]]
      ...> new = [one: [one_sub: [a: 2, c: 1]], two: {1, "foo", :baz, :qux}, three: 'a new charlist', four: [1, 2, 4, 6]]
      ...> #{__MODULE__}.merge(old, new)
      [one: [one_sub: [a: 2, b: 2, c: 1]], two: {1, "foo", :baz, :qux}, three: 'a new charlist', four: [1, 2, 4, 6]]
  """
  def merge(old, new) when is_list(old) and is_list(new),
    do: merge(old, new, [])

  defp merge([{_old_key, old_value} = h | t], new, acc) when is_tuple(h) do
    case :lists.keytake(elem(h, 0), 1, new) do
      {:value, {new_key, new_value}, rest} ->
        # Value is present in new, so merge the value
        merged = merge_term(old_value, new_value)
        merge(t, rest, [{new_key, merged}|acc])
      false ->
        # Value doesn't exist in new, so add it
        merge(t, new, [h|acc])
    end
  end
  defp merge([], new, acc) do
    Enum.reverse(acc, new)
  end

  defp merge_term([hold|told] = old, [hnew|tnew] = new) when is_list(new) do
    cond do
      :io_lib.char_list(old) && :io_lib.char_list(new) ->
        new
      Keyword.keyword?(old) && Keyword.keyword?(new) ->
        Keyword.merge(old, new, fn (_key, old_val, new_val) -> merge_term(old_val, new_val) end)
        |> Enum.sort_by(fn {k, _} -> k end)
      true ->
        [merge_term(hold, hnew) | merge_term(told, tnew)]
    end
  end
  defp merge_term([], new) when is_list(new), do: new
  defp merge_term(old, []) when is_list(old), do: old

  defp merge_term(old, new) when is_tuple(old) and is_tuple(new) do
    merged = old
    |> Tuple.to_list
    |> Enum.with_index
    |> Enum.reduce([], fn
        {[], idx}, acc ->
          [elem(new, idx)|acc]
        {val, idx}, acc when is_list(val) ->
          case :io_lib.char_list(val) do
            true ->
              [elem(new, idx) | acc]
            false ->
              merged = merge_term(val, elem(new, idx))
              [merged | acc]
          end
        {val, idx}, acc when is_tuple(val) ->
          [merge_term(val, elem(new, idx)) | acc]
        {val, idx}, acc ->
          [(elem(new, idx) || val) | acc]
       end)
    |> Enum.reverse

    merged_count = Enum.count(merged)
    extra_count  = :erlang.size(new) - merged_count

    case extra_count do
      0 -> merged
      _ ->
        extra = new
          |> Tuple.to_list
          |> Enum.slice(merged_count, extra_count)
        List.to_tuple(merged ++ extra)
    end
  end

  defp merge_term(old, nil),  do: old
  defp merge_term(_old, new), do: new


  @doc """
  Recursively sorts a keyword list such that keys are in ascending alphabetical order

  ## Example

      iex> kwlist = [a: 1, c: 2, b: 3, d: [z: 99, w: 50, x: [a_2: 1, a_1: 2]]]
      ...> #{__MODULE__}.sort_kwlist(kwlist)
      [a: 1, b: 3, c: 2, d: [w: 50, x: [a_1: 2, a_2: 1], z: 99]]
  """
  def sort_kwlist(kwlist) when is_list(kwlist) do
    case Keyword.keyword?(kwlist) do
      true ->
        kwlist = Enum.sort_by(kwlist, fn {k, _} -> k end)
        Keyword.merge(kwlist, kwlist, fn
          (_, v, _) when is_list(v) ->
            sort_kwlist(v)
          (_, v, _) ->
            v
        end)
      false ->
        kwlist
    end
  end
  def sort_kwlist(val), do: val

  @doc """
  Searches a list of tuples (pairs) where the first element of the tuple
  matches the provided key. This is used in the Translate module, and expects
  keys in the form of lists of charlists, i.e. `['some', 'key', 'path']`

  It accepts wildcards in the match key, i.e. `['some', '*', 'path']`

  ## Examples

      iex> list = [{['some', 'foo', 'bar'], 1}, {['some', 'foo', 'baz'], 2}, {['some', 'bar', 'baz'], 3}]
      ...> #{__MODULE__}.search_pairs(['some', 'foo', 'bar'], list)
      [{['some', 'foo', 'bar'], 1}]
      ...> #{__MODULE__}.search_pairs(['some', '*', 'baz'], list)
      [{['some', 'foo', 'baz'], 1}, {['some', 'bar', 'baz'], 3}]
      ...> #{__MODULE__}.search_pairs(['foo', 'bar'], list)
      nil
      ...> #{__MODULE__}.search_pairs(['foo', 'bar'], list, [])
      []

  """
  def search_pairs(key, list, default \\ nil) do
    search_pairs(key, list, default, [])
  end

  defp search_pairs(_, [], default, []),   do: default
  defp search_pairs(_, [], _default, acc), do: acc |> Enum.reverse
  defp search_pairs(key, [{hkey, _} = h|rest], default, acc) do
    case is_match(key, hkey) do
      false -> search_pairs(key, rest, default, acc)
      true  -> search_pairs(key, rest, default, [h|acc])
    end
  end

  defp is_match(key, key),   do: true
  defp is_match(key1, key2), do: match_key_part(key1, key2, nil)

  defp match_key_part(['*'|rest1], [_|rest2], _) do
    match_key_part(rest1, rest2, '*')
  end
  defp match_key_part([part1|rest1], [part1|rest2], _) do
    match_key_part(rest1, rest2, part1)
  end
  defp match_key_part([_|_], [_|_], _), do: false
  defp match_key_part([], _, '*'),      do: true
  defp match_key_part([], [], _),       do: true
  defp match_key_part([], _, _),        do: false

end
