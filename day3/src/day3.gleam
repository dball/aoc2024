import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/regexp
import simplifile

pub fn main() {
  let path = "./input.txt"
  let assert Ok(data) = simplifile.read(path)
  let assert Ok(mul_re) =
    regexp.from_string("(do|don\\'t)\\(\\)|(mul)\\((\\d+),(\\d+)\\)")
  let matches = regexp.scan(mul_re, data)
  let result =
    list.fold(matches, #(True, 0), fn(accum, match) {
      let #(do, sum) = accum
      case do {
        True -> {
          case match.submatches {
            [option.None, option.Some("mul"), option.Some(x), option.Some(y)] -> {
              let assert Ok(x) = int.parse(x)
              let assert Ok(y) = int.parse(y)
              #(True, sum + x * y)
            }
            [option.Some("don't")] -> #(False, sum)
            _ -> #(do, sum)
          }
        }
        False -> {
          case match.submatches {
            [option.Some("do")] -> #(True, sum)
            _ -> #(do, sum)
          }
        }
      }
    })
  io.debug(result)
}
