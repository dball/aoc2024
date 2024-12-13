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
  Region(crop: String, origin: Point, area: Int, perimeter: Int, sides: Int)
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

fn conj_plot(garden: Garden, plot: Plot) -> Garden {
  let w = project(plot.point, W)
  let nw = project(w, N)
  let n = project(nw, E)
  let ne = project(n, E)
  let wr = find_region(garden, w)
  let nwr = find_region(garden, nw)
  let nr = find_region(garden, n)
  let ner = find_region(garden, ne)
  let joins = fn(region: Option(Region)) {
    case region {
      Some(region) if region.crop == plot.crop -> Some(region)
      _ -> None
    }
  }
  let wra = joins(wr)
  let nwra = joins(nwr)
  let nra = joins(nr)
  let nera = joins(ner)
  let #(add, delete) = case wra, nwra, nra, nera {
    Some(region), Some(_), Some(_), Some(_) -> {
      #(Region(..region, area: region.area + 1), None)
    }
    None, Some(region), Some(_), Some(_) -> {
      #(
        Region(
          ..region,
          area: region.area + 1,
          perimeter: region.perimeter + 2,
          sides: region.sides + 4,
        ),
        None,
      )
    }
    None, None, Some(region), Some(_) -> {
      #(
        Region(
          ..region,
          area: region.area + 1,
          perimeter: region.perimeter + 2,
          sides: region.sides + 2,
        ),
        None,
      )
    }
    Some(region), Some(_), Some(_), None -> {
      #(Region(..region, area: region.area + 1, sides: region.sides - 2), None)
    }
    None, Some(region), Some(_), None -> {
      #(
        Region(
          ..region,
          area: region.area + 1,
          perimeter: region.perimeter + 2,
          sides: region.sides + 2,
        ),
        None,
      )
    }
    Some(region), Some(_), None, _ -> {
      #(
        Region(
          ..region,
          area: region.area + 1,
          perimeter: region.perimeter + 2,
          sides: region.sides + 2,
        ),
        None,
      )
    }
    Some(region), None, None, _ -> {
      #(
        Region(..region, area: region.area + 1, perimeter: region.perimeter + 2),
        None,
      )
    }
    None, None, Some(region), None -> {
      #(
        Region(..region, area: region.area + 1, perimeter: region.perimeter + 2),
        None,
      )
    }
    Some(region1), None, Some(region2), None -> {
      case region1.origin == region2.origin {
        True -> #(
          Region(..region1, area: region1.area + 1, sides: region1.sides - 2),
          None,
        )
        False -> {
          #(
            Region(
              ..region1,
              area: region1.area + region2.area + 1,
              perimeter: region1.perimeter + region2.perimeter,
              sides: region1.sides + region2.sides - 2,
            ),
            Some(region2),
          )
        }
      }
    }
    Some(region1), None, Some(region2), Some(_) -> {
      case region1.origin == region2.origin {
        True -> #(Region(..region1, area: region1.area + 1), None)
        False -> {
          #(
            Region(
              ..region1,
              area: region1.area + region2.area + 1,
              perimeter: region1.perimeter + region2.perimeter,
              sides: region1.sides + region2.sides,
            ),
            Some(region2),
          )
        }
      }
    }
    None, _, None, _ -> {
      #(Region(plot.crop, plot.point, 1, 4, 4), None)
    }
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

fn compute_bulk_fence_price(garden: Garden) -> Int {
  dict.values(garden.regions_by_origin)
  |> list.fold(0, fn(total, region) { total + region.area * region.sides })
}

pub fn main() {
  let path = "input.txt"
  let assert Ok(input) = simplifile.read(path)
  let garden = parse_input(input)
  io.debug(compute_fence_price(garden))
  io.debug(compute_bulk_fence_price(garden))
  io.println("Done")
}
