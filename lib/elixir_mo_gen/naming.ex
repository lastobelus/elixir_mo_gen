defmodule ElixirMoGen.Naming do
  @moduledoc """
  Conveniences for inflecting and working with names, copied from Phoenix:

  https://github.com/phoenixframework/phoenix/blob/master/lib/phoenix/naming.ex

  """

  @doc """
  Extracts the resource name from an alias.

  ## Examples

      iex> ElixirMoGen.Naming.resource_name(MyApp.User)
      "user"

      iex> ElixirMoGen.Naming.resource_name(MyApp.UserView, "View")
      "user"

  """
  @spec resource_name(String.Chars.t(), String.t()) :: String.t()
  def resource_name(alias, suffix \\ "") do
    alias
    |> to_string()
    |> Module.split()
    |> List.last()
    |> unsuffix(suffix)
    |> underscore()
  end

  @doc """
  Removes the given suffix from the name if it exists.

  ## Examples

      iex> ElixirMoGen.Naming.unsuffix("MyApp.User", "View")
      "MyApp.User"

      iex> ElixirMoGen.Naming.unsuffix("MyApp.UserView", "View")
      "MyApp.User"

  """
  @spec unsuffix(String.t(), String.t()) :: String.t()
  def unsuffix(value, suffix) do
    string = to_string(value)
    suffix_size = byte_size(suffix)
    prefix_size = byte_size(string) - suffix_size

    case string do
      <<prefix::binary-size(prefix_size), ^suffix::binary>> -> prefix
      _ -> string
    end
  end

  @doc """
  Converts a string to underscore case, first converting any hyphens
  to underscores.

  ## Examples

      iex> ElixirMoGen.Naming.underscore("MyApp")
      "my_app"

  In general, `underscore` can be thought of as the reverse of
  `camelize`, however, in some cases formatting may be lost:

      ElixirMoGen.Naming.underscore "SAPExample"  #=> "sap_example"
      ElixirMoGen.Naming.camelize   "sap_example" #=> "SapExample"

  """
  @spec underscore(String.t()) :: String.t()

  def underscore(value), do: Macro.underscore(dedasherize(value))
  defp dedasherize(str), do: String.replace(str, "-", "_")

  defp to_lower_char(char) when char in ?A..?Z, do: char + 32
  defp to_lower_char(char), do: char

  @doc """
  Converts a string to camel case.

  Takes an optional `:lower` flag to return lowerCamelCase.

  ## Examples

      iex> ElixirMoGen.Naming.camelize("my_app")
      "MyApp"

      iex> ElixirMoGen.Naming.camelize("my_app", :lower)
      "myApp"

  In general, `camelize` can be thought of as the reverse of
  `underscore`, however, in some cases formatting may be lost:

      ElixirMoGen.Naming.underscore "SAPExample"  #=> "sap_example"
      ElixirMoGen.Naming.camelize   "sap_example" #=> "SapExample"

  """
  @spec camelize(String.t()) :: String.t()
  def camelize(value), do: Macro.camelize(value)

  @spec camelize(String.t(), :lower) :: String.t()
  def camelize("", :lower), do: ""

  def camelize(<<?_, t::binary>>, :lower) do
    camelize(t, :lower)
  end

  def camelize(<<h, _t::binary>> = value, :lower) do
    <<_first, rest::binary>> = camelize(value)
    <<to_lower_char(h)>> <> rest
  end

  @doc """
  Converts an attribute/form field into its humanize version.

  ## Examples

      iex> ElixirMoGen.Naming.humanize(:username)
      "Username"
      iex> ElixirMoGen.Naming.humanize(:created_at)
      "Created at"
      iex> ElixirMoGen.Naming.humanize("user_id")
      "User"

  """
  @spec humanize(atom | String.t()) :: String.t()
  def humanize(atom) when is_atom(atom),
    do: humanize(Atom.to_string(atom))

  def humanize(bin) when is_binary(bin) do
    bin =
      if String.ends_with?(bin, "_id") do
        binary_part(bin, 0, byte_size(bin) - 3)
      else
        bin
      end

    bin |> String.replace("_", " ") |> String.capitalize()
  end
end
