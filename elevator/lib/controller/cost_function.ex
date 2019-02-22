defmodule CostFunction do
    # Check if an elevator is in IDLE
    # Traverse through order list
    # Calculate cost, given state, current direction, last passed floor


    def direction_to_int(direction) do
        case direction do
            :up -> 1
            :down -> -1
            :stop -> 0
            _ -> {:error,:nonexistent_dir}
        end
    end

    def traverse_order_list() do
        
    end

    def calculate_cost(state,curr_floor,state) do
        case state do
            :idle ->

            :mooving ->

            :init ->
        end
    end


end
