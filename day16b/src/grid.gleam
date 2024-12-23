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
  directions |> list.map(project(point, _))
}

pub type Grid(a) {
  Grid(contents: Dict(Point, a), max: Point)
}

pub fn parse_grid(input: String, parse_cell: fn(String) -> Option(a)) -> Grid(a) {
  let lines = string.split(input, "\n")
  let grid = Grid(contents: dict.new(), max: Point(-1, list.length(lines)))
  list.index_fold(lines, grid, fn(grid, line, y) {
    let chars = string.to_graphemes(line)
    let max = Point(..grid.max, x: list.length(chars))
    list.index_fold(chars, Grid(..grid, max: max), fn(grid, char, x) {
      let contents = case parse_cell(char) {
        Some(value) -> dict.insert(grid.contents, Point(x, y), value)
        None -> grid.contents
      }
      Grid(..grid, contents: contents)
    })
  })
}

pub fn render_grid(
  grid: Grid(a),
  render_cell: fn(Option(a)) -> String,
) -> String {
  let xs = list.range(0, grid.max.x - 1)
  let ys = list.range(0, grid.max.y - 1)
  list.fold(ys, string_tree.new(), fn(st, y) {
    list.fold(xs, st, fn(st, x) {
      get_content(grid, Point(x, y)) |> render_cell |> string_tree.append(st, _)
    })
    |> string_tree.append("\n")
  })
  |> string_tree.to_string
}

pub fn get_content(grid: Grid(a), point: Point) -> Option(a) {
  case dict.get(grid.contents, point) {
    Ok(value) -> Some(value)
    Error(_) -> None
  }
}

pub fn has_contents(grid: Grid(a), point: Point) -> Bool {
  dict.has_key(grid.contents, point)
}

pub fn get_neighboring_contents(
  grid: Grid(a),
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
