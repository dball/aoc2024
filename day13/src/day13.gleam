import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regexp
import gleam/result
import gleam/string
import simplifile

type Machine {
  Machine(ax: Int, ay: Int, bx: Int, by: Int, px: Int, py: Int)
}

type Arcade =
  List(Machine)

type Solution {
  Solution(a: Int, b: Int)
}

fn parse_machine(input: String) -> Machine {
  let assert Ok(a_re) = regexp.from_string("^Button A: X\\+(\\d+), Y\\+(\\d+)$")
  let assert Ok(b_re) = regexp.from_string("^Button B: X\\+(\\d+), Y\\+(\\d+)$")
  let assert Ok(p_re) = regexp.from_string("^Prize: X=(\\d+), Y=(\\d+)$")
  let assert [a, b, p] = string.split(input, "\n")
  let assert [ma] = regexp.scan(a_re, a)
  let assert [Some(ax), Some(ay)] = ma.submatches
  let assert [mb] = regexp.scan(b_re, b)
  let assert [Some(bx), Some(by)] = mb.submatches
  let assert [mp] = regexp.scan(p_re, p)
  let assert [Some(px), Some(py)] = mp.submatches
  Machine(
    result.unwrap(int.parse(ax), 0),
    result.unwrap(int.parse(ay), 0),
    result.unwrap(int.parse(bx), 0),
    result.unwrap(int.parse(by), 0),
    result.unwrap(int.parse(px), 0),
    result.unwrap(int.parse(py), 0),
  )
}

fn parse_input(input: String) -> Arcade {
  list.map(string.split(input, "\n\n"), parse_machine)
}

fn solve_machine(machine: Machine) -> Option(Solution) {
  let Machine(ax, ay, bx, by, px, py) = machine
  let ad = bx * ay - ax * by
  case ad {
    0 -> None
    _ -> {
      let an = py * bx - px * by
      let remainder = an % ad
      case remainder {
        0 -> {
          let a = an / ad
          let bn = px - ax * a
          let remainder = bn % bx
          case remainder {
            0 -> {
              let b = bn / bx
              Some(Solution(a, b))
            }
            _ -> None
          }
        }
        _ -> None
      }
    }
  }
}

fn token_cost(solution: Solution) -> Int {
  let Solution(a, b) = solution
  a * 3 + b
}

fn total_cost(arcade: Arcade) -> Int {
  list.map(arcade, solve_machine)
  |> list.map(option.unwrap(_, Solution(0, 0)))
  |> list.map(token_cost)
  |> list.fold(0, int.add)
}

fn adjust_prizes(arcade: Arcade, px: Int, py: Int) -> Arcade {
  list.map(arcade, fn(machine) {
    Machine(..machine, px: machine.px + px, py: machine.py + py)
  })
}

pub fn main() {
  let path = "input.txt"
  let assert Ok(data) = simplifile.read(path)
  let arcade = parse_input(data)
  io.debug(total_cost(arcade))
  let arcade = adjust_prizes(arcade, 10_000_000_000_000, 10_000_000_000_000)
  io.debug(total_cost(arcade))
  io.println("Done")
}
