# LiftProject
Our lift project is written in Elixir, a functional programming language.

For the extensive specifications for the project, see the [course project site](https://github.com/TTK4145/Project).

Our distribution system for orders relies on the concept of auctions and bids, where the lift with the lowest cost for the respective order will be assigned the order. In addition, all orders are assigned a watchdog in the form of another node in the network. If the order isn't completed within a specific time, it's redistributed.

## File descriptions
###### I/O Poller
Handles all of input and outputs, eg. polling floor- and button sensors.
###### Lift
Takes care of basic lift performance, driving the lift towards a specific order and stopping when reaching a wanted floor.
###### Node Discovery
Discovers and connect to new nodes on the network and broadcast existence to the network.
###### Order Distribution
Distributes orders to nodes based on a cost calculation in addition to redistributing orders given from the watchdog.
###### Order Server
Keeps track of orders collected from Order Distribution, in addition to setting hall lights and calculating the cost of a given order for the respective lift.
###### Order
Sets the structure of an order in addition to tests if order is at a given floor.
###### Watchdog
Takes care of any order not being handled within reasonable time, set by the timer length @watchdog_timer.
###### File back up
Reads and writes to file to keep a record of the current and previous states.

## Supervision
The supervision tree implemented, is shown below.

![picture](supervision_tree.png)

## Assumptions
###### Functional
- No multiple simultaneous errors.
- At least one lift is always working normally.
- A person ordering the lift down will follow up with a cab call below for optimal performance from the system.
- Since the use of the obstruction switch and stop button is optional, we have chosen to not add this to our project.
###### Code design
- Since private functions can't be accessed externally, Elixir will warn if a private function has a @doc attribute and will discard its content. We have therefore excluded docs and other comments regarding implementation of functions in private functions.
- Further design is based on the given [requirements](https://github.com/TTK4145/Project2018/blob/master/EVALUATION.md#code-evaluation).
- Documentation for point of entry can be found in "Application" as this is the module that is called first.
- Documentation is assumed to give the reader a explanation of what the code is going to do and why, rather than how it is implemented.

## Dependencies
- Elevator Server
- Dependencies for each module are specified in the respective module documentation

## Accreditations
Snippets of Jostein Løwer's code at his [repository](https://github.com/jostlowe/kokeplata) has been used as inspiration in some of our modules. There are also some functions from his examples which are used directly. For more details on Jostein's code, see the documentation.
