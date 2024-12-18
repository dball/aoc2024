import gleam/dict.{type Dict}
import gleam/int
import gleam/io
import gleam/list.{Continue, Stop}
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

// TODO remove the boxes first
fn move_boxes(
  warehouse: Warehouse,
  boxes: Set(Box),
  direction: Direction,
) -> Option(Warehouse) {
  case set.is_subset(boxes, warehouse.boxes) {
    False -> None
    True -> {
      let warehouse =
        Warehouse(..warehouse, boxes: set.difference(warehouse.boxes, boxes))
      let next_boxes =
        set.map(boxes, fn(box) {
          Box(set.map(box.locations, project(_, direction)))
        })
      let next_locations =
        set.fold(next_boxes, set.new(), fn(accum, box) {
          set.union(accum, box.locations)
        })
      case set.is_empty(set.intersection(warehouse.walls, next_locations)) {
        True -> {
          let boxes_to_move =
            set.filter(warehouse.boxes, fn(box) {
              !set.is_empty(set.intersection(next_locations, box.locations))
            })
          let warehouse =
            Warehouse(
              ..warehouse,
              boxes: set.union(warehouse.boxes, next_boxes),
            )
          case set.is_empty(boxes_to_move) {
            True -> Some(warehouse)
            False -> {
              io.debug(#(
                "MOVING BOXES",
                boxes,
                next_boxes,
                boxes_to_move,
                direction,
              ))
              move_boxes(warehouse, boxes_to_move, direction)
            }
          }
        }
        False -> None
      }
    }
  }
}

fn move_robot(warehouse: Warehouse, direction: Direction) -> Warehouse {
  let robot = warehouse.robot
  let next_location = project(robot.location, direction)
  case set.contains(warehouse.walls, next_location) {
    True -> warehouse
    False -> {
      let boxes =
        set.filter(warehouse.boxes, fn(box) {
          set.contains(box.locations, next_location)
        })
      case move_boxes(warehouse, boxes, direction) {
        None -> warehouse
        Some(warehouse) -> {
          let robot = Robot(..robot, location: next_location)
          let warehouse = Warehouse(..warehouse, robot: robot)
          io.println(case direction {
            N -> "N"
            S -> "S"
            E -> "E"
            W -> "W"
          })
          io.println(render_warehouse(warehouse))
          warehouse
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

fn compute_box_gps(warehouse: Warehouse, box: Box) -> Int {
  let xs =
    box.locations
    |> set.map(fn(point) { point.x })
    |> set.to_list
    |> list.sort(int.compare)
  let assert Ok(minx) = list.first(xs)
  let assert Ok(maxx) = list.last(xs)
  let lx = minx
  let rx = warehouse.width - maxx - 1
  let assert Ok(point) = box.locations |> set.to_list |> list.first
  case lx < rx {
    True -> compute_gps(Point(lx, point.y))
    False -> compute_gps(Point(rx, point.y))
  }
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
  let path = "input0.txt"
  let assert Ok(data) = simplifile.read(path)
  let warehouse = parse_input(data)
  io.debug(warehouse)
  io.println(render_warehouse(warehouse))
  let finished = follow_all_instructions(warehouse)
  let total =
    set.fold(finished.boxes, 0, fn(total, box) {
      total + compute_box_gps(finished, box)
    })
  io.println(int.to_string(total))
  io.println("Done")
}
