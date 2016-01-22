defmodule Conform.Utils.Code do
  @moduledoc """
  This module provides handy utilities for low-level
  manipulation of Elixir's AST. Currently, it's primary
  purpose is for stringification of schemas for printing
  or writing to disk.
  """

  @doc """
  Takes a schema in quoted form and produces a string
  representation of that schema for printing or writing
  to disk.
  """
  def stringify(schema) do
    schema |> Macro.postwalk([], fn ast, _node -> {ast, []} end) |> elem(0) |> Macro.to_string
  end
end
