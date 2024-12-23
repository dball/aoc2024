import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/string_tree

pub type Point {
  Point(x: Int, y: Int)
}

pub type Direction {
  N
  S
  E
  W
}

pub const directions = [N, E, S, W]

pub type Turn {
  Left
  Right
}

pub fn turn(direction: Direction, turn: Turn) -> Direction {
  case direction, turn {
    N, Left -> W
    N, Right -> E
    E, Left -> N
    E, Right -> S
    S, Left -> E
    S, Right -> W
    W, Left -> S
    W, Right -> N
  }
}

pub fn opposite(direction: Direction) -> Direction {
  case direction {
    N -> S
    S -> N
    E -> W
    W -> E
  }
}

pub fn project(point: Point, direction: Direction) -> Point {
  case direction {
    N -> Point(..point, y: point.y - 1)
    S -> Point(..point, y: point.y + 1)
    E -> Point(..point, x: point.x + 1)
    W -> Point(..point, x: point.x - 1)
  }
}

pub fn neighboring_points(point: Point) -> List(Point) {
  [N, E, S, W] |> list.map(project(point, _))
}

pub fn parse_grid(
  input: String,
  parse_cell: fn(String) -> Option(a),
) -> #(Dict(Point, a), Point) {
  let lines = string.split(input, "\n")
  let init = #(dict.new(), Point(-1, list.length(lines)))
  list.index_fold(lines, init, fn(accum, line, y) {
    let chars = string.to_graphemes(line)
    let #(grid, max) = accum
    let max = Point(..max, x: list.length(chars))
    list.index_fold(chars, #(grid, max), fn(accum, char, x) {
      let #(grid, max) = accum
      case parse_cell(char) {
        Some(value) -> #(dict.insert(grid, Point(x, y), value), max)
        None -> #(grid, max)
      }
    })
  })
}

pub fn render_grid(
  grid: Dict(Point, a),
  max: Point,
  render_cell: fn(Option(a)) -> String,
) -> String {
  let xs = list.range(0, max.x - 1)
  let ys = list.range(0, max.y - 1)
  list.fold(ys, string_tree.new(), fn(st, y) {
    list.fold(xs, st, fn(st, x) {
      get_content(grid, Point(x, y)) |> render_cell |> string_tree.append(st, _)
    })
    |> string_tree.append("\n")
  })
  |> string_tree.to_string
}

pub fn get_content(grid: Dict(Point, a), point: Point) -> Option(a) {
  case dict.get(grid, point) {
    Ok(value) -> Some(value)
    Error(_) -> None
  }
}

pub fn has_contents(grid: Dict(Point, a), point: Point) -> Bool {
  dict.has_key(grid, point)
}

pub fn get_neighboring_contents(
  grid: Dict(Point, a),
  point: Point,
) -> List(#(Point, a)) {
  neighboring_points(point)
  |> list.fold([], fn(accum, neighbor) {
    case get_content(grid, neighbor) {
      Some(value) -> [#(neighbor, value), ..accum]
      None -> accum
    }
  })
}
