import gleam/dict.{type Dict}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/set.{type Set}
import gleam/string
import simplifile

type Pair =
  #(Int, Int)

type Run =
  List(Int)

type Rules =
  List(Pair)

type RuleSet =
  Dict(Int, Set(Int))

fn build_ruleset(rules: Rules) -> RuleSet {
  list.fold(rules, dict.new(), fn(rule_set, rule) {
    let #(before, after) = rule
    rule_set
    |> dict.upsert(before, fn(afters) {
      case afters {
        Some(pages) -> set.insert(pages, after)
        None -> set.from_list([after])
      }
    })
    |> dict.upsert(after, fn(afters) {
      case afters {
        Some(pages) -> pages
        None -> set.new()
      }
    })
  })
}

fn expand_ruleset(rule_set: RuleSet) -> RuleSet {
  dict.map_values(rule_set, fn(_, afters) {
    set.fold(afters, afters, fn(accum, after) {
      let assert Ok(pages) = dict.get(rule_set, after)
      set.union(accum, pages)
    })
  })
}

// Here we get into some areas where types impede, perhaps?
// This is just recursively applying a fn until a fixed point.
// Can we do that with generic foo?
fn fully_expand(rule_set: RuleSet) -> RuleSet {
  let new_rule_set = expand_ruleset(rule_set)
  case new_rule_set == rule_set {
    True -> rule_set
    False -> fully_expand(new_rule_set)
  }
}

fn valid(rule_set: RuleSet, run: Run) {
  case run {
    [] -> True
    [_] -> True
    [before, after] ->
      case dict.get(rule_set, before) {
        Ok(afters) -> set.contains(afters, after)
        Error(_) -> False
      }
    [before, after, ..rest] ->
      valid(rule_set, [before, after]) && valid(rule_set, [after, ..rest])
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

// Again with the genericify?
fn midpoint(items: List(Int)) -> Int {
  let n = list.length(items)
  let assert Ok(v) = list.drop(items, n / 2) |> list.first()
  v
}

pub fn main() {
  let path = "./input.txt"
  let assert Ok(data) = simplifile.read(path)
  let #(rules, runs) = parse_input(data)
  let rule_set = build_ruleset(rules) |> fully_expand
  let valids = list.filter(runs, valid(rule_set, _))
  let assert Ok(midpoints) = list.map(valids, midpoint) |> list.reduce(int.add)
  io.debug(midpoints)
}
