import gleam/dict.{type Dict}
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
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

fn build_xs(word: String) -> Option(List(Board)) {
  let chars = string.to_graphemes(word)
  let n = list.length(chars)
  case n % 2 {
    1 -> {
      Some([
        list.index_fold(chars, dict.new(), fn(board, char, i) {
          let board = dict.insert(board, #(i, i), char)
          dict.insert(board, #(n - i - 1, i), char)
        }),
        list.index_fold(chars, dict.new(), fn(board, char, i) {
          let board = dict.insert(board, #(i, i), char)
          dict.insert(board, #(i, n - i - 1), char)
        }),
        list.index_fold(chars, dict.new(), fn(board, char, i) {
          let board = dict.insert(board, #(n - i - 1, n - i - 1), char)
          dict.insert(board, #(n - i - 1, i), char)
        }),
        list.index_fold(chars, dict.new(), fn(board, char, i) {
          let board = dict.insert(board, #(n - i - 1, n - i - 1), char)
          dict.insert(board, #(i, n - i - 1), char)
        }),
      ])
    }
    _ -> None
  }
}

fn translate(board: Board, delta: Point) -> Board {
  dict.fold(board, dict.new(), fn(translation, key, value) {
    let #(i, j) = key
    let #(di, dj) = delta
    dict.insert(translation, #(i + di, j + dj), value)
  })
}

fn contains(board: Board, projection: Board) -> Bool {
  list.all(dict.keys(projection), fn(k) {
    dict.get(projection, k) == dict.get(board, k)
  })
}

pub fn main() {
  let path = "./input.txt"
  let word = "MAS"
  let assert Ok(data) = simplifile.read(path)
  let lines = string.split(data, "\n")
  let board = build_board(lines)
  let assert Some(xs) = build_xs(word)
  let points = dict.keys(board)
  let finds =
    list.flat_map(points, fn(point) {
      list.map(xs, fn(x) {
        let projection = translate(x, point)
        contains(board, projection)
      })
    })
  let count = list.count(finds, fn(x) { x })
  io.debug(count)
}
