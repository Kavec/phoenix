defmodule Mix.Tasks.Phoenix.Gen.Html do
  use Mix.Task

  @shortdoc "Generates controller, model and views for an HTML based resource"

  @moduledoc """
  Generates a Phoenix resource.

      mix phoenix.gen.html User users name:string age:integer

  The first argument is the module name followed by
  its plural name (used for resources and schema).

  The generated resource will contain:

    * a model in web/models
    * a view in web/views
    * a controller in web/controllers
    * a migration file for the repository
    * default CRUD templates in web/templates
    * test files for generated model and controller

  The generated model can be skipped with `--no-model`.
  Read the documentation for `phoenix.gen.model` for more
  information on attributes and namespaced resources.
  """
  def run(args) do
    {opts, parsed, _} = OptionParser.parse(args, switches: [model: :boolean])
    [singular, plural | attrs] = validate_args!(parsed)

    attrs   = Mix.Phoenix.attrs(attrs)
    binding = Mix.Phoenix.inflect(singular)
    path    = binding[:path]
    route   = String.split(path, "/") |> Enum.drop(-1) |> Kernel.++([plural]) |> Enum.join("/")
    binding = binding ++ [plural: plural, route: route, attrs: attrs,
                          inputs: inputs(attrs), params: Mix.Phoenix.params(attrs),
                          template_singular: String.replace(binding[:singular], "_", " "),
                          template_plural: String.replace(plural, "_", " ")]

    Mix.Phoenix.check_module_name_availability!(binding[:module] <> "Controller")
    Mix.Phoenix.check_module_name_availability!(binding[:module] <> "View")

    Mix.Phoenix.copy_from paths(), "priv/templates/phoenix.gen.html", "", binding, [
      {:eex, "controller.ex",       "web/controllers/#{path}_controller.ex"},
      {:eex, "edit.html.eex",       "web/templates/#{path}/edit.html.eex"},
      {:eex, "form.html.eex",       "web/templates/#{path}/form.html.eex"},
      {:eex, "index.html.eex",      "web/templates/#{path}/index.html.eex"},
      {:eex, "new.html.eex",        "web/templates/#{path}/new.html.eex"},
      {:eex, "show.html.eex",       "web/templates/#{path}/show.html.eex"},
      {:eex, "view.ex",             "web/views/#{path}_view.ex"},
      {:eex, "controller_test.exs", "test/controllers/#{path}_controller_test.exs"},
    ]

    instructions = """

    Add the resource to your browser scope in web/router.ex:

        resources "/#{route}", #{binding[:scoped]}Controller
    """

    if opts[:model] != false do
      Mix.Task.run "phoenix.gen.model", ["--instructions", instructions|args]
    else
      Mix.shell.info instructions
    end
  end

  defp validate_args!([_, plural | _] = args) do
    cond do
      String.contains?(plural, ":") ->
        raise_with_help
      plural != Phoenix.Naming.underscore(plural) ->
        Mix.raise "expected the second argument, #{inspect plural}, to be all lowercase using snake_case convention"
      true ->
        args
    end
  end

  defp validate_args!(_) do
    raise_with_help
  end

  defp raise_with_help do
    Mix.raise """
    mix phoenix.gen.html expects both singular and plural names
    of the generated resource followed by any number of attributes:

        mix phoenix.gen.html User users name:string
    """
  end

  defp inputs(attrs) do
    Enum.map attrs, fn
      {_, {:array, _}} ->
        {nil, nil}
      {_, {:references, _}} ->
        {nil, nil}
      {key, :integer}    ->
        {inspect(key), label(key), ~s(<%= number_input f, #{inspect(key)}, class: "form-control" %>)}
      {key, :float}      ->
        {inspect(key), label(key), ~s(<%= number_input f, #{inspect(key)}, step: "any", class: "form-control" %>)}
      {key, :decimal}    ->
        {inspect(key), label(key), ~s(<%= number_input f, #{inspect(key)}, step: "any", class: "form-control" %>)}
      {key, :boolean}    ->
        {inspect(key), label(key), ~s(<%= checkbox f, #{inspect(key)}, class: "form-control" %>)}
      {key, :text}       ->
        {inspect(key), label(key), ~s(<%= textarea f, #{inspect(key)}, class: "form-control" %>)}
      {key, :date}       ->
        {inspect(key), label(key), ~s(<%= date_select f, #{inspect(key)}, class: "form-control" %>)}
      {key, :time}       ->
        {inspect(key), label(key), ~s(<%= time_select f, #{inspect(key)}, class: "form-control" %>)}
      {key, :datetime}   ->
        {inspect(key), label(key), ~s(<%= datetime_select f, #{inspect(key)}, class: "form-control" %>)}
      {key, _}           ->
        {inspect(key), label(key), ~s(<%= text_input f, #{inspect(key)}, class: "form-control" %>)}
    end
  end

  defp label(key) do
    label_text = Phoenix.Naming.humanize(key)
    ~s(<%= label f, #{inspect(key)}, "#{label_text}", class: "control-label" %>)
  end

  defp paths do
    [".", :phoenix]
  end
end
