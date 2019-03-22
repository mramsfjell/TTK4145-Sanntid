defmodule CostFunction do
    # INPUT  -  current order_list to each lift
    #           last passed floor
    #           node_id til den som 
    #           new order {type,floor} -- type: :cab/:hall_up/:hall_down
    #           direction
    #           current state

    # OUTPUT -  Integer cost


    # Consider INIT-function


    ## Helper function
    # Unsure if this is applicable
    defp direction_to_int(direction) do
        case direction do
            :up -> 1
            :down -> -1
            :stop -> 0
            _ -> {:error,:invalid_direction}
        end
    end

    defp traverse_order_list(direction,order_list,order) do
        # Go through each element in order list
    end

    

    ## Calculate cost

    # When cab call -- separate between own cabcall & others
    # SEE order_list.ex Order module
    
    def calculate_cost(:idle,curr_floor,{_type,floor},_direction) do
        abs(curr_floor - floor)
    end

    def calculate_cost(state,curr_floor,{type,floor},direction) do
        # When mooving or door_open
    end

end
