import gleam/bool
import gleam/int
import gleam/io
import gleam/list.{Continue, Stop}
import gleam/order.{type Order, Eq, Gt, Lt}
import gleam/set.{type Set}
import gleam/string
import simplifile

type Pair =
  #(Int, Int)

type Run =
  List(Int)

type Rules =
  List(Pair)

fn build_violations(rules: Rules) -> Set(Pair) {
  list.map(rules, fn(rule) {
    let #(before, after) = rule
    #(after, before)
  })
  |> set.from_list()
}

fn valid(violations: Set(Pair), run: Run) -> Bool {
  let state =
    list.fold_until(run, #([], True), fn(state, page) {
      let #(preceding, _) = state
      let invalid =
        list.any(preceding, fn(ppage) {
          set.contains(violations, #(ppage, page))
        })
      case invalid {
        True -> Stop(#([], False))
        False -> Continue(#([page, ..preceding], True))
      }
    })
  let #(_, valid) = state
  valid
}

fn conj(violations: Set(Pair), run: Run, page: Int) -> Run {
  case run {
    [] -> [page]
    _ -> {
      let #(before, after) =
        list.split_while(run, fn(ppage) {
          set.contains(violations, #(ppage, page))
        })
      list.flatten([before, [page], after])
    }
  }
}

fn sort(violations: Set(Pair), run: Run) -> Run {
  list.fold(run, [], fn(accum, page) { conj(violations, accum, page) })
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

fn midpoint(items: List(Int)) -> Int {
  let n = list.length(items)
  let assert Ok(v) = list.drop(items, n / 2) |> list.first()
  v
}

pub fn main() {
  let path = "./input.txt"
  let assert Ok(data) = simplifile.read(path)
  let #(rules, runs) = parse_input(data)
  let violations = build_violations(rules)
  let valids = list.filter(runs, valid(violations, _))
  let assert Ok(midpoints) = list.map(valids, midpoint) |> list.reduce(int.add)
  io.debug(midpoints)
  let invalids = list.filter(runs, fn(run) { !valid(violations, run) })
  let sorted_runs = list.map(invalids, fn(run) { sort(violations, run) })
  let assert Ok(sorted_midpoints) =
    list.map(sorted_runs, midpoint) |> list.reduce(int.add)
  io.debug(sorted_midpoints)
}
