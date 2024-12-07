import gleam/int
import gleam/io
import gleam/list
import gleam/string
import simplifile

type Op {
  Add
  Mult
  Cat
}

type Comparison {
  // The scalars are reversed from the input for efficient narrowing
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

fn has_solution(comparison: Comparison, ops: List(Op)) -> Bool {
  let Comparison(result, scalars) = comparison
  let solved = case scalars {
    [] -> result == 0
    [x] -> x == result
    // Maybe unnecessary but easier to reason about so bite me
    [x, y] ->
      list.contains(ops, Mult)
      && x * y == result
      || list.contains(ops, Add)
      && x + y == result
      || list.contains(ops, Cat)
      && int.to_string(result)
      == string.concat([int.to_string(y), int.to_string(x)])
    [x, ..rest] -> {
      // Also maybe this could/should be just an or expr but, eh
      list.any(ops, fn(op) {
        case op {
          Mult -> {
            case result % x == 0 {
              True ->
                has_solution(Comparison(result: result / x, scalars: rest), ops)
              False -> False
            }
          }
          Add -> {
            let remainder = result - x
            case remainder > 0 {
              True ->
                has_solution(Comparison(result: remainder, scalars: rest), ops)
              False -> False
            }
          }
          Cat -> {
            let result_string = int.to_string(result)
            let x_string = int.to_string(x)
            case
              string.length(result_string) > string.length(x_string)
              && string.ends_with(result_string, x_string)
            {
              True -> {
                let assert Ok(remainder) =
                  int.parse(string.drop_end(
                    result_string,
                    string.length(x_string),
                  ))
                has_solution(Comparison(result: remainder, scalars: rest), ops)
              }
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
    |> list.filter(has_solution(_, [Mult, Add]))
    |> list.map(fn(comparison) { comparison.result })
    |> list.fold(0, int.add)
  io.debug(solvables)

  let solvables =
    comparisons
    |> list.filter(has_solution(_, [Mult, Add, Cat]))
    |> list.map(fn(comparison) { comparison.result })
    |> list.fold(0, int.add)
  io.debug(solvables)
}
