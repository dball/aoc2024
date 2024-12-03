import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/regexp
import simplifile

pub fn main() {
  let path = "./input.txt"
  let assert Ok(data) = simplifile.read(path)
  let assert Ok(mul_re) = regexp.from_string("mul\\((\\d+),(\\d+)\\)")
  let matches = regexp.scan(mul_re, data)
  let multiplies =
    list.map(matches, fn(match) {
      case match.submatches {
        [option.Some(x), option.Some(y)] -> {
          let assert Ok(x) = int.parse(x)
          let assert Ok(y) = int.parse(y)
          x * y
        }
        _ -> 0
      }
    })
  let result = list.fold(multiplies, 0, int.add)
  io.debug(result)
}
