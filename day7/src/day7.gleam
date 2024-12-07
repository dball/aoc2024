import gleam/int
import gleam/io
import gleam/list.{type ContinueOrStop, Continue, Stop}
import gleam/option.{type Option, None, Some}
import gleam/string
import simplifile

type Op {
  Add
  Mult
}

type Comparison {
  Comparison(result: Int, scalars: List(Int))
}

fn parse_input(data: String) -> List(Comparison) {
  let lines = string.split(data, "\n")
  list.map(lines, fn(line) {
    let assert Ok(#(result, values)) = string.split_once(line, ": ")
    let assert Ok(result) = int.parse(result)
    let scalars =
      string.split(values, " ")
      |> list.map(fn(s) {
        let assert Ok(x) = int.parse(s)
        x
      })
      |> list.reverse
    Comparison(result: result, scalars: scalars)
  })
}

fn has_solution(comparison: Comparison) -> Bool {
  let Comparison(result, scalars) = comparison
  let solved = case scalars {
    [] -> result == 0
    [x] -> x == result
    [x, y] -> x * y == result || x + y == result
    [x, ..rest] -> {
      list.any([Mult, Add], fn(op) {
        case op {
          Mult -> {
            case result % x == 0 {
              True ->
                has_solution(Comparison(result: result / x, scalars: rest))
              False -> False
            }
          }
          Add -> {
            let remainder = result - x
            case remainder > 0 {
              True -> has_solution(Comparison(result: remainder, scalars: rest))
              False -> False
            }
          }
        }
      })
    }
  }
  //io.debug(#(comparison, solved))
  solved
}

pub fn main() {
  let path = "input.txt"
  let assert Ok(data) = simplifile.read(path)
  let comparisons = parse_input(data)
  let solvables =
    comparisons
    |> list.filter(has_solution)
    |> list.map(fn(comparison) { comparison.result })
    |> list.fold(0, int.add)
  io.debug(solvables)
}
