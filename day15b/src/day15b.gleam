import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/set.{type Set}
import gleam/string
import gleam/string_tree
import simplifile

type Point {
  Point(x: Int, y: Int)
}

type Direction {
  N
  S
  E
  W
}

fn project(point: Point, direction: Direction) -> Point {
  case direction {
    N -> Point(..point, y: point.y - 1)
    S -> Point(..point, y: point.y + 1)
    E -> Point(..point, x: point.x + 1)
    W -> Point(..point, x: point.x - 1)
  }
}

type Robot {
  Robot(location: Point, instructions: List(Direction))
}

type Box {
  Box(locations: Set(Point))
}

type Warehouse {
  Warehouse(
    robot: Robot,
    boxes: Set(Box),
    walls: Set(Point),
    width: Int,
    height: Int,
  )
}

fn parse_input(input: String) -> Warehouse {
  let assert Ok(#(grid, instructions)) = string.split_once(input, "\n\n")
  let instructions =
    instructions
    |> string.to_graphemes
    |> list.fold([], fn(accum, char) {
      let direction = case char {
        "<" -> Some(W)
        "^" -> Some(N)
        ">" -> Some(E)
        "v" -> Some(S)
        _ -> None
      }
      case direction {
        Some(direction) -> [direction, ..accum]
        None -> accum
      }
    })
    |> list.reverse
  let robot = Robot(Point(-1, -1), instructions)
  let lines = string.split(grid, "\n")
  let warehouse = Warehouse(robot, set.new(), set.new(), -1, list.length(lines))
  lines
  |> list.index_fold(warehouse, fn(warehouse, line, y) {
    let chars = string.to_graphemes(line)
    list.index_fold(chars, warehouse, fn(warehouse, char, hx) {
      let lpoint = Point(hx * 2, y)
      let rpoint = Point(hx * 2 + 1, y)
      case char {
        "#" -> {
          let walls =
            warehouse.walls |> set.insert(lpoint) |> set.insert(rpoint)
          Warehouse(..warehouse, walls: walls)
        }
        "O" -> {
          let box =
            Box(
              locations: set.new() |> set.insert(lpoint) |> set.insert(rpoint),
            )
          Warehouse(..warehouse, boxes: warehouse.boxes |> set.insert(box))
        }
        "@" -> {
          let robot = Robot(..robot, location: lpoint)
          Warehouse(..warehouse, robot: robot, width: list.length(chars) * 2)
        }
        _ -> warehouse
      }
    })
  })
}

fn move_boxes(
  warehouse: Warehouse,
  boxes: Set(Box),
  direction: Direction,
) -> Option(Warehouse) {
  io.println("moving boxes")
  io.println(render_direction(direction))
  //io.println(render_warehouse(warehouse))
  io.debug(boxes)
  let boxes_after_moving =
    set.map(boxes, fn(box) {
      Box(set.map(box.locations, project(_, direction)))
    })
  let box_destinations =
    set.fold(boxes_after_moving, set.new(), fn(accum, box) {
      set.union(accum, box.locations)
    })
  io.debug(#("boxes after moving", boxes_after_moving))
  io.debug(#("box destinations", box_destinations))
  case set.is_empty(set.intersection(warehouse.walls, box_destinations)) {
    True -> {
      io.println("no walls")
      let boxes_to_move_next =
        set.filter(warehouse.boxes, fn(box) {
          !set.is_empty(set.intersection(box_destinations, box.locations))
        })
      case set.is_empty(boxes_to_move_next) {
        True -> {
          io.println("no boxes to move further")
          Some(
            Warehouse(
              ..warehouse,
              boxes: set.union(warehouse.boxes, boxes_after_moving),
            ),
          )
        }
        False -> {
          io.println("trying to move more boxes")
          move_boxes(
            Warehouse(
              ..warehouse,
              boxes: set.difference(warehouse.boxes, boxes_to_move_next)
                |> set.union(boxes_after_moving),
            ),
            boxes_to_move_next,
            direction,
          )
        }
      }
    }
    False -> {
      io.println("hit a wall")
      None
    }
  }
}

fn render_direction(direction: Direction) -> String {
  case direction {
    N -> "N"
    S -> "S"
    E -> "E"
    W -> "W"
  }
}

fn move_robot(warehouse: Warehouse, direction: Direction) -> Warehouse {
  io.println("moving robot")
  io.println(render_direction(direction))
  //io.println(render_warehouse(warehouse))
  let robot = warehouse.robot
  let next_location = project(robot.location, direction)
  case set.contains(warehouse.walls, next_location) {
    True -> warehouse
    False -> {
      let boxes =
        set.filter(warehouse.boxes, fn(box) {
          set.contains(box.locations, next_location)
        })
      let robot = Robot(..robot, location: next_location)
      case set.is_empty(boxes) {
        True -> {
          io.println("robot moved easily")
          Warehouse(..warehouse, robot: robot)
        }
        _ -> {
          case
            move_boxes(
              Warehouse(
                ..warehouse,
                boxes: set.difference(warehouse.boxes, boxes),
              ),
              boxes,
              direction,
            )
          {
            None -> {
              io.println("robot could not move")
              warehouse
            }
            Some(warehouse) -> {
              io.println("robot moved to")
              let warehouse = Warehouse(..warehouse, robot: robot)
              //io.println(render_warehouse(warehouse))
              warehouse
            }
          }
        }
      }
    }
  }
}

fn follow_all_instructions(warehouse: Warehouse) -> Warehouse {
  let robot = warehouse.robot
  case robot.instructions {
    [] -> warehouse
    [direction, ..rest] -> {
      let robot = Robot(..robot, instructions: rest)
      let warehouse =
        Warehouse(..warehouse, robot: robot) |> move_robot(direction)
      follow_all_instructions(warehouse)
    }
  }
}

fn compute_gps(point: Point) -> Int {
  100 * point.y + point.x
}

fn compute_box_gps(box: Box) -> Int {
  let assert Ok(x) =
    box.locations
    |> set.map(fn(point) { point.x })
    |> set.to_list
    |> list.sort(int.compare)
    |> list.first
  let assert Ok(point) = box.locations |> set.to_list |> list.first
  compute_gps(Point(x: x, y: point.y))
}

fn render_warehouse(warehouse: Warehouse) -> String {
  let chars =
    dict.new()
    |> dict.insert(warehouse.robot.location, "@")
    |> set.fold(
      warehouse.walls,
      _,
      fn(chars, wall) { dict.insert(chars, wall, "#") },
    )
    |> set.fold(
      warehouse.boxes,
      _,
      fn(chars, box) {
        set.fold(box.locations, chars, fn(chars, location) {
          dict.insert(chars, location, "[")
        })
      },
    )

  list.range(0, warehouse.height)
  |> list.fold(string_tree.new(), fn(st, y) {
    list.range(0, warehouse.width)
    |> list.fold(st, fn(st, x) {
      let point = Point(x, y)
      case dict.get(chars, point) {
        Ok(char) -> string_tree.append(st, char)
        Error(_) -> string_tree.append(st, ".")
      }
    })
    |> string_tree.append("\n")
  })
  |> string_tree.to_string
}

pub fn main() {
  let path = "input.txt"
  let assert Ok(data) = simplifile.read(path)
  let warehouse = parse_input(data)
  let finished = follow_all_instructions(warehouse)
  let total =
    set.fold(finished.boxes, 0, fn(total, box) { total + compute_box_gps(box) })
  io.println(int.to_string(total))
  io.println("Done")
}
