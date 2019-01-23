defmodule Math do
    def sum(a, b) do
        a + b
    end
end


# Anonymous functions -- two common practices
sum = fn(a, b) -> a + b end
sum.(2, 3) #Gives out 5

sum = &(&1 + &2)
sum.(2, 3) #Gives out 5


# Functions and modules
defmodule Greeter do
    def hello(name) do
        "Hello, " <> name
    end
end
Greeter.hello("Simen")  # "Hello, Simen"

defmodule Length do
    def of([]), do: 0
    def of([_ | tail]), do: 1 + of(tail)
end
Length.of []        # Gives 0
Length.of [1, 3, 5] # Gives 3

defmodule Greeter2 do
    def hello(), do: "Hello, anon"
    def hello(name), do: "Hello, " <> name
    def hello(name1, name2), do: "Hello, #{name1} and #{name2}"
end

#Private funcs & Default value for argument
defmodule PrivateGreeter do
    def hello(name, language_code \\ "en") do
        phrase(language_code) <> name
    end

    defp phrase("en"), do: "Hello, "
    defp phrase("no"), do: "Hei, "
    defp phrase("es"), do: "Hola, "
end
