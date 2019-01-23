defmodule Math do
    def sum(a, b) do
        a + b
    end
end

# List
list = [3.1415, :pie, "Apple"]
["Test"] ++ list        # ["Test", 3.1415, :pie, "Apple"]

list ++ ["Test"]        # [3.1415, :pie, "Apple", "Test"]
