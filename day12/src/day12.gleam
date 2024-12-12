import gleam/dict.{type Dict}
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

type Point {
  Point(x: Int, y: Int)
}

type Direction {
  N
  S
  E
  W
}

fn project(point: Point, direction: Direction) -> Point {
  case direction {
    N -> Point(..point, y: point.y - 1)
    S -> Point(..point, y: point.y + 1)
    W -> Point(..point, x: point.x - 1)
    E -> Point(..point, x: point.x + 1)
  }
}

type Region {
  Region(crop: String, origin: Point, area: Int, perimeter: Int)
}

type Garden {
  Garden(
    regions_by_origin: Dict(Point, Region),
    origins_by_point: Dict(Point, Point),
  )
}

type Plot {
  Plot(crop: String, point: Point)
}

fn find_region(garden: Garden, point: Point) -> Option(Region) {
  case dict.get(garden.origins_by_point, point) {
    Ok(origin) -> {
      let assert Ok(region) = dict.get(garden.regions_by_origin, origin)
      Some(region)
    }
    Error(_) -> None
  }
}

// Always add from west to east (increasing x), north to south (increasing y)
fn conj_plot(garden: Garden, plot: Plot) -> Garden {
  let region = {
    case find_region(garden, project(plot.point, W)) {
      Some(neighbor) if neighbor.crop == plot.crop -> {
        Region(
          ..neighbor,
          area: neighbor.area + 1,
          perimeter: neighbor.perimeter + 2,
        )
      }
      _ -> Region(plot.crop, plot.point, 1, 4)
    }
  }
  let region = {
    case find_region(garden, project(plot.point, N)) {
      Some(neighbor) if neighbor.crop == plot.crop -> {
        Region(
          ..neighbor,
          area: neighbor.area + 1,
          perimeter: neighbor.perimeter + 2,
        )
      }
      _ -> region
    }
  }
  Garden(
    dict.insert(garden.regions_by_origin, region.origin, region),
    dict.insert(garden.origins_by_point, plot.point, region.origin),
  )
}

fn parse_input(s: String) -> Garden {
  let lines = string.split(s, "\n")
  let garden = Garden(dict.new(), dict.new())
  list.index_fold(lines, garden, fn(garden, line, y) {
    let chars = string.to_graphemes(line)
    list.index_fold(chars, garden, fn(garden, char, x) {
      let plot = Plot(char, Point(x, y))
      // WTF I get different output if the debug runs or not????
      //io.debug(plot)
      conj_plot(garden, plot)
    })
  })
}

pub fn main() {
  let input = "ABA\nAAA"
  let garden = parse_input(input)
  io.debug(garden)
  io.println("Done")
}
