import gleam/dict.{type Dict}
import gleam/io
import gleam/list
import gleam/string
import simplifile

type Point =
  #(Int, Int)

type Board =
  Dict(Point, String)

fn fill_board(board: Board, i: Int, lines: List(String)) -> Board {
  case lines {
    [] -> board
    [first, ..rest] -> {
      let chars = string.to_graphemes(first)
      let board =
        list.index_fold(chars, board, fn(board, char, j) {
          dict.insert(board, #(i, j), char)
        })
      fill_board(board, i + 1, rest)
    }
  }
}

fn build_board(lines: List(String)) -> Board {
  fill_board(dict.new(), 0, lines)
}

type Direction {
  N
  S
  E
  W
  NE
  NW
  SE
  SW
}

fn next(direction: Direction, point: Point) -> Point {
  let #(i, j) = point
  case direction {
    N -> #(i, j - 1)
    S -> #(i, j + 1)
    E -> #(i + 1, j)
    W -> #(i - 1, j)
    NE -> #(i + 1, j - 1)
    SE -> #(i + 1, j + 1)
    NW -> #(i - 1, j - 1)
    SW -> #(i - 1, j + 1)
  }
}

fn project(
  word: String,
  direction: Direction,
  point: Point,
  board: Board,
) -> Board {
  case string.pop_grapheme(word) {
    Ok(#(first, rest)) ->
      project(
        rest,
        direction,
        next(direction, point),
        dict.insert(board, point, first),
      )
    _ -> board
  }
}

fn project_all(word: String, point: Point) -> List(Board) {
  [
    project(word, N, point, dict.new()),
    project(word, S, point, dict.new()),
    project(word, E, point, dict.new()),
    project(word, W, point, dict.new()),
    project(word, NE, point, dict.new()),
    project(word, NW, point, dict.new()),
    project(word, SE, point, dict.new()),
    project(word, SW, point, dict.new()),
  ]
}

fn contains(board: Board, projection: Board) -> Bool {
  board == dict.combine(board, projection, fn(_, y) { y })
}

fn finds(board: Board, word: String, point: Point) -> Int {
  let projections = project_all(word, point)
  list.count(projections, fn(projection) { contains(board, projection) })
}

pub fn main() {
  let path = "./input.txt"
  let word = "XMAS"
  let assert Ok(data) = simplifile.read(path)
  let lines = string.split(data, "\n")
  let board = build_board(lines)
  let points = dict.keys(board)
  let count =
    list.fold(points, 0, fn(accum, point) {
      //io.debug(point)
      accum + finds(board, word, point)
    })
  io.debug(count)
}
