import gleam/dict.{type Dict}
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/set.{type Set}
import gleam/string
import simplifile

type Point =
  #(Int, Int)

type City {
  City(extent: Point, antennas: Dict(String, Set(Point)))
}

fn parse_input(data: String) -> City {
  let lines = string.split(data, "\n")
  let city = City(extent: #(0, 0), antennas: dict.new())
  list.index_fold(lines, city, fn(city, line, j) {
    let chars = string.to_graphemes(line)
    let width = list.length(chars)
    let City(extent, _) = city
    let #(last_width, _) = extent
    // This time, we assume the city is a rectangle, instead of building
    // a dictionary of locations, which allowed for irregular maps.
    let extent = case width > last_width {
      True -> #(width, j + 1)
      False -> #(last_width, j + 1)
    }
    list.index_fold(chars, City(..city, extent: extent), fn(city, char, i) {
      let City(_, antennas) = city
      case char {
        "." -> city
        _ -> {
          let point = #(i, j)
          let antennas =
            dict.upsert(antennas, char, fn(points) {
              case points {
                Some(points) -> set.insert(points, point)
                None -> set.new() |> set.insert(point)
              }
            })
          City(..city, antennas: antennas)
        }
      }
    })
  })
}

fn within_limits(city: City, point: Point) -> Bool {
  let #(i, j) = point
  let #(mi, mj) = city.extent
  i >= 0 && j >= 0 && i < mi && j < mj
}

fn project_antinodes(points: Set(Point)) -> Set(Point) {
  let pairs = set.to_list(points) |> list.combination_pairs
  list.fold(pairs, set.new(), fn(antinodes, pair) {
    let #(x, y) = pair
    let #(xi, xj) = x
    let #(yi, yj) = y
    let di = yi - xi
    let dj = yj - xj
    antinodes
    |> set.insert(#(yi + di, yj + dj))
    |> set.insert(#(xi - di, xj - dj))
  })
}

fn project_city_antinodes(city: City) -> Set(Point) {
  dict.fold(city.antennas, set.new(), fn(all_antinodes, _, points) {
    project_antinodes(points)
    |> set.filter(within_limits(city, _))
    |> set.union(all_antinodes)
  })
}

pub fn main() {
  let path = "input.txt"
  let assert Ok(data) = simplifile.read(path)
  let city = parse_input(data)
  let count = project_city_antinodes(city) |> set.size
  io.debug(count)
}
