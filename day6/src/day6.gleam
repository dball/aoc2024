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

type Vector {
  Vector(point: Point, direction: Direction)
}

type Guard {
  Guard(
    point: Option(Point),
    history: List(Vector),
    direction: Direction,
    looping: Bool,
  )
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

fn advance_guard(board: Board) -> Board {
  let Board(locations, guard) = board
  let Guard(point, history, direction, _) = guard
  case point {
    Some(point) -> {
      let next = next_point(point, direction)
      case dict.get(locations, next) {
        Ok(Obstacle) -> {
          let next_direction = clockwise(direction)
          let vector = Vector(point, next_direction)
          let guard =
            Guard(
              ..guard,
              direction: next_direction,
              history: [vector, ..history],
            )
          Board(..board, guard: guard)
        }
        Ok(Empty) -> {
          let vector = Vector(next, direction)
          case list.find(history, fn(v) { vector == v }) {
            Ok(_) -> {
              let guard =
                Guard(
                  ..guard,
                  point: Some(next),
                  history: [vector, ..history],
                  looping: True,
                )
              Board(..board, guard: guard)
            }
            Error(_) -> {
              let guard =
                Guard(..guard, point: Some(next), history: [vector, ..history])
              Board(..board, guard: guard)
            }
          }
        }
        Error(_) -> {
          let guard = Guard(..guard, point: None)
          Board(..board, guard: guard)
        }
      }
    }
    None -> board
  }
}

fn advance_guard_until_gone(board: Board) -> Board {
  let board = advance_guard(board)
  case board.guard {
    Guard(_, _, _, True) -> board
    Guard(None, _, _, _) -> board
    _ -> advance_guard_until_gone(board)
  }
}

fn parse_input(data: String) -> Board {
  let lines = string.split(data, "\n")
  let board =
    Board(
      locations: dict.new(),
      guard: Guard(point: None, history: [], direction: N, looping: False),
    )
  list.index_fold(lines, board, fn(board, line, i) {
    let chars = string.to_graphemes(line)
    list.index_fold(chars, board, fn(board, char, j) {
      let point = #(i, j)
      let Board(locations, guard) = board
      case char {
        "." -> Board(..board, locations: dict.insert(locations, point, Empty))
        "#" ->
          Board(..board, locations: dict.insert(locations, point, Obstacle))
        "^" -> {
          let guard =
            Guard(
              ..guard,
              point: Some(point),
              history: [Vector(point, guard.direction)],
            )
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
  let guard = advanced.guard
  let points = set.from_list(guard.history)
  io.debug(set.size(points))

  let potentia =
    guard.history
    |> list.map(fn(vector) { vector.point })
    |> set.from_list

  let loopers =
    potentia
    |> set.filter(fn(point) {
      let board =
        Board(..board, locations: dict.insert(board.locations, point, Obstacle))
      let advanced = advance_guard_until_gone(board)
      advanced.guard.looping
    })
    |> set.size
  io.debug(loopers)
}
