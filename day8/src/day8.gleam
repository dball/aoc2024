import gleam/dict.{type Dict}
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/set.{type Set}
import gleam/string
import gleam/yielder
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

fn point_add(p1: Point, p2: Point) -> Point {
  #(p1.0 + p2.0, p1.1 + p2.1)
}

fn point_subtract(p1: Point, p2: Point) -> Point {
  #(p1.0 - p2.0, p1.1 - p2.1)
}

fn project_antinodes(
  city: City,
  harmonics: Bool,
  points: Set(Point),
) -> Set(Point) {
  let within = within_limits(city, _)
  let pairs = set.to_list(points) |> list.combination_pairs
  list.fold(pairs, set.new(), fn(antinodes, pair) {
    let #(x, y) = pair
    let d = point_subtract(y, x)
    case harmonics {
      False -> {
        let new_points =
          set.new()
          |> set.insert(point_add(y, d))
          |> set.insert(point_subtract(x, d))
          |> set.filter(within)
        set.union(antinodes, new_points)
      }
      True -> {
        let from_y =
          yielder.iterate(y, point_add(_, d))
          |> yielder.take_while(within)
          |> yielder.to_list
          |> set.from_list
        let from_x =
          yielder.iterate(x, point_subtract(_, d))
          |> yielder.take_while(within)
          |> yielder.to_list
          |> set.from_list
        set.union(antinodes, set.union(from_x, from_y))
      }
    }
  })
}

fn project_city_antinodes(city: City, harmonics: Bool) -> Set(Point) {
  dict.fold(city.antennas, set.new(), fn(all_antinodes, _, points) {
    project_antinodes(city, harmonics, points)
    |> set.union(all_antinodes)
  })
}

pub fn main() {
  let path = "input.txt"
  let assert Ok(data) = simplifile.read(path)
  let city = parse_input(data)
  let count = project_city_antinodes(city, False) |> set.size
  io.debug(count)
  let count = project_city_antinodes(city, True) |> set.size
  io.debug(count)
}
