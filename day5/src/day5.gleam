import gleam/int
import gleam/io
import gleam/list
import gleam/string
import rememo/memo
import simplifile

type Pair =
  #(Int, Int)

type Run =
  List(Int)

type Rules =
  List(Pair)

fn permute(first: Int, rest: List(Int)) -> List(List(Int)) {
  list.index_map(rest, fn(_, i) {
    list.flatten([[first], list.take(rest, i), list.drop(rest, i + 1)])
  })
}

fn valid(rules: Rules, run: Run, cache) {
  use <- memo.memoize(cache, run)
  io.debug(#("validating", run))
  case run {
    [] -> True
    [_] -> True
    [x, y] -> list.all(rules, fn(rule) { rule != #(y, x) })
    [first, ..rest] -> {
      valid(rules, rest, cache)
      && list.all(permute(first, rest), fn(run) { valid(rules, run, cache) })
    }
  }
}

fn parse_input(data: String) -> #(Rules, List(Run)) {
  let assert Ok(#(part1, part2)) = string.split_once(data, "\n\n")
  let rules =
    list.map(string.split(string.trim(part1), "\n"), fn(line) {
      let assert Ok(#(first, last)) = string.split_once(line, "|")
      let assert Ok(i) = int.parse(first)
      let assert Ok(j) = int.parse(last)
      #(i, j)
    })
  let runs =
    list.map(string.split(string.trim(part2), "\n"), fn(line) {
      let numbers = string.split(line, ",")
      list.map(numbers, fn(number) {
        let assert Ok(i) = int.parse(number)
        i
      })
    })
  #(rules, runs)
}

pub fn main() {
  let path = "./input.txt"
  let assert Ok(data) = simplifile.read(path)
  let #(rules, runs) = parse_input(data)
  use cache <- memo.create()
  let total =
    runs
    |> list.filter(valid(rules, _, cache))
    |> list.map(fn(run) {
      let n = list.length(run)
      let assert Ok(midpoint) = list.drop(run, n / 2) |> list.first()
      midpoint
    })
    |> list.reduce(int.add)
  io.debug(total)
}
