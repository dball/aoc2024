import gleam/dict.{type Dict}
import gleam/int
import gleam/io
import gleam/list.{Continue, Stop}
import gleam/option.{type Option, None, Some}
import gleam/set.{type Set}
import gleam/string
import gleam/yielder.{type Step, type Yielder, Done, Next}
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

type Projection =
  Yielder(Point)

fn build_projection(point: Point, direction: Direction) -> Projection {
  yielder.iterate(point, project(_, direction))
}

type Occupant {
  Robot(instructions: List(Direction))
  Wall
  Box
}

type Warehouse =
  Dict(Point, Occupant)

fn move_objects(
  warehouse: Warehouse,
  occupant: Occupant,
  projection: Projection,
) -> Result(Warehouse, Nil) {
  let assert Next(first, rest) = yielder.step(projection)
  case dict.get(warehouse, first) {
    Error(_) -> Ok(dict.insert(warehouse, first, occupant))
    Ok(Wall) | Ok(Robot(_)) -> Error(Nil)
    Ok(Box) -> move_objects(dict.insert(warehouse, first, occupant), Box, rest)
  }
}

fn move_robot(
  warehouse: Warehouse,
  from: Point,
  direction: Direction,
) -> Warehouse {
  let assert Ok(Robot(instructions)) = dict.get(warehouse, from)
  let projection = build_projection(from, direction) |> yielder.drop(1)
  case
    move_objects(dict.delete(warehouse, from), Robot(instructions), projection)
  {
    Ok(warehouse) -> warehouse
    Error(_) -> warehouse
  }
}

fn follow_all_instructions(warehouse: Warehouse) -> Warehouse {
  let robots =
    dict.to_list(warehouse)
    |> list.filter(fn(entry) {
      let #(_, occupant) = entry
      case occupant {
        Robot(_) -> True
        _ -> False
      }
    })
  list.fold(robots, warehouse, fn(warehouse, entry) {
    let assert #(location, Robot(instructions)) = entry
    case instructions {
      [] -> warehouse
      [direction, ..rest] ->
        follow_all_instructions(move_robot(
          dict.insert(warehouse, location, Robot(rest)),
          location,
          direction,
        ))
    }
  })
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
  grid
  |> string.split("\n")
  |> list.index_fold(dict.new(), fn(warehouse, line, y) {
    let chars = string.to_graphemes(line)
    list.index_fold(chars, warehouse, fn(warehouse, char, x) {
      let point = Point(x, y)
      case char {
        "#" -> dict.insert(warehouse, point, Wall)
        "O" -> dict.insert(warehouse, point, Box)
        "@" -> dict.insert(warehouse, point, Robot(instructions))
        _ -> warehouse
      }
    })
  })
}

fn compute_gps(point: Point) -> Int {
  100 * point.y + point.x
}

pub fn main() {
  let path = "input.txt"
  let assert Ok(data) = simplifile.read(path)
  let warehouse = parse_input(data)
  let total =
    follow_all_instructions(warehouse)
    |> dict.fold(0, fn(total, point, occupant) {
      case occupant {
        Box -> total + compute_gps(point)
        _ -> total
      }
    })
  io.println(int.to_string(total))
  io.println("Done")
}
