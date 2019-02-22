defmodule CostFunction do
    # INPUT  -  current order_list to each lift
    #           last passed floor
    #           new order (floor, type - :cab/:hall)
    #           direction
    #           current state

    ## Unsure if this is applicable
    def direction_to_int(direction) do
        case direction do
            :up -> 1
            :down -> -1
            :stop -> 0
            _ -> {:error,:invalid_direction}
        end
    end



    def traverse_order_list(direction,order_list,order) do
        # Go through each element in order list
    end

    # When cab call 
    
    def calculate_cost(:idle,curr_floor,{_type,floor},_direction) do
        abs(curr_floor - floor)
    end

    def calculate_cost(state,curr_floor,{type,floor},direction) do
        # When mooving or door_open
    end

end
