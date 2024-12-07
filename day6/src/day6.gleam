import gleam/dict.{type Dict}
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/set
import gleam/string
import simplifile

type Point =
  #(Int, Int)

type Board {
  Board(locations: Dict(Point, Location), guard: Guard)
}

type Guard {
  Guard(point: Point, history: List(Point), facing: Direction)
}

type Location {
  Empty
  Obstacle
}

type Direction {
  N
  S
  E
  W
}

fn next_point(point: Point, direction: Direction) -> Point {
  let #(i, j) = point
  case direction {
    N -> #(i - 1, j)
    S -> #(i + 1, j)
    E -> #(i, j + 1)
    W -> #(i, j - 1)
  }
}

fn clockwise(direction: Direction) -> Direction {
  case direction {
    N -> E
    E -> S
    S -> W
    W -> N
  }
}

fn advance_guard(board: Board) -> Option(Board) {
  let Board(locations, guard) = board
  let Guard(point, history, facing) = guard
  let next = next_point(point, facing)
  case dict.get(locations, next) {
    Ok(Obstacle) -> {
      let guard = Guard(..guard, facing: clockwise(facing))
      Some(Board(..board, guard: guard))
    }
    Ok(Empty) -> {
      let guard = Guard(..guard, point: next, history: [next, ..history])
      Some(Board(..board, guard: guard))
    }
    Error(_) -> {
      None
    }
  }
}

// Higher order pattern here? Iterate until None
fn advance_guard_until_gone(board: Board) -> Board {
  let next = advance_guard(board)
  case next {
    Some(board) -> advance_guard_until_gone(board)
    None -> board
  }
}

fn parse_input(data: String) -> Board {
  let lines = string.split(data, "\n")
  let board =
    Board(
      locations: dict.new(),
      guard: Guard(point: #(0, 0), history: [], facing: N),
    )
  list.index_fold(lines, board, fn(board, line, i) {
    let chars = string.to_graphemes(line)
    list.index_fold(chars, board, fn(board, char, j) {
      let point = #(i, j)
      let Board(locations, _) = board
      case char {
        "." -> Board(..board, locations: dict.insert(locations, point, Empty))
        "#" ->
          Board(..board, locations: dict.insert(locations, point, Obstacle))
        "^" -> {
          let guard = Guard(..board.guard, point: point, history: [point])
          Board(locations: dict.insert(locations, point, Empty), guard: guard)
        }
        _ -> board
      }
    })
  })
}

pub fn main() {
  let path = "input.txt"
  let assert Ok(data) = simplifile.read(path)
  let board = parse_input(data)
  let advanced = advance_guard_until_gone(board)
  let points = set.from_list(advanced.guard.history)
  io.debug(set.size(points))
}
