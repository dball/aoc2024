import gleam/dict.{type Dict}
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import simplifile

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
    N -> Point(x: point.x, y: point.y - 1)
    S -> Point(x: point.x, y: point.y + 1)
    W -> Point(y: point.y, x: point.x - 1)
    E -> Point(y: point.y, x: point.x + 1)
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
  let west = find_region(garden, project(plot.point, W))
  let north = find_region(garden, project(plot.point, N))
  let #(add, delete) = case west, north {
    Some(west), Some(north)
      if west.crop == plot.crop
      && north.crop == plot.crop
      && west.origin != north.origin
    -> {
      #(
        Region(
          ..west,
          area: west.area + north.area + 1,
          perimeter: west.perimeter + north.perimeter,
        ),
        Some(north),
      )
    }
    Some(west), Some(north)
      if west.crop == plot.crop && north.crop == plot.crop
    -> {
      #(Region(..west, area: west.area + 1), None)
    }
    Some(west), _ if west.crop == plot.crop -> #(
      Region(..west, area: west.area + 1, perimeter: west.perimeter + 2),
      None,
    )
    _, Some(north) if north.crop == plot.crop -> #(
      Region(..north, area: north.area + 1, perimeter: north.perimeter + 2),
      None,
    )
    _, _ -> #(Region(plot.crop, plot.point, 1, 4), None)
  }
  let garden =
    Garden(
      dict.insert(garden.regions_by_origin, add.origin, add),
      dict.insert(garden.origins_by_point, plot.point, add.origin),
    )
  case delete {
    None -> garden
    Some(delete) -> {
      Garden(
        dict.delete(garden.regions_by_origin, delete.origin),
        dict.map_values(garden.origins_by_point, fn(_, origin) {
          case origin == delete.origin {
            True -> add.origin
            False -> origin
          }
        }),
      )
    }
  }
}

fn parse_input(s: String) -> Garden {
  let lines = string.split(s, "\n")
  let garden = Garden(dict.new(), dict.new())
  list.index_fold(lines, garden, fn(garden, line, y) {
    let chars = string.to_graphemes(line)
    list.index_fold(chars, garden, fn(garden, char, x) {
      let plot = Plot(char, Point(x, y))
      conj_plot(garden, plot)
    })
  })
}

fn compute_fence_price(garden: Garden) -> Int {
  dict.values(garden.regions_by_origin)
  |> list.fold(0, fn(total, region) { total + region.area * region.perimeter })
}

pub fn main() {
  let path = "input.txt"
  let assert Ok(input) = simplifile.read(path)
  let garden = parse_input(input)
  io.debug(compute_fence_price(garden))
  io.println("Done")
}
