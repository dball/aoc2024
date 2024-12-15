import gleam/dict
import gleam/function
import gleam/int
import gleam/io
import gleam/list.{Continue, Stop}
import gleam/option.{type Option, None, Some}
import gleam/regexp
import gleam/result
import gleam/set
import gleam/string
import gleam/string_tree
import gleam/yielder.{type Yielder}
import simplifile

type Point {
  Point(x: Int, y: Int)
}

type Robot {
  Robot(location: Point, velocity: Point)
}

type Area {
  Area(width: Int, height: Int, center: Point)
}

fn move_robot(robot: Robot, area: Area) -> Robot {
  let Robot(location, velocity) = robot
  let x = { area.width + location.x + velocity.x } % area.width
  let y = { area.height + location.y + velocity.y } % area.height
  Robot(..robot, location: Point(x, y))
}

fn parse_robot(input: String) -> Robot {
  let assert Ok(re) =
    regexp.from_string("^p=(\\d+),(\\d+) v=(-?\\d+),(-?\\d+)$")
  let assert [match] = regexp.scan(re, input)
  let parse = fn(m) { result.unwrap(int.parse(option.unwrap(m, "")), 0) }
  let assert [x, y, vx, vy] = list.map(match.submatches, parse)
  Robot(location: Point(x, y), velocity: Point(vx, vy))
}

fn find_quadrant(area: Area, point: Point) -> Option(Point) {
  let dx = area.center.x - point.x
  let dy = area.center.y - point.y
  case dx, dy {
    dx, dy if dx < 0 && dy < 0 -> Some(Point(-1, -1))
    dx, dy if dx < 0 && dy > 0 -> Some(Point(-1, 1))
    dx, dy if dx > 0 && dy < 0 -> Some(Point(1, -1))
    dx, dy if dx > 0 && dy > 0 -> Some(Point(1, 1))
    _, _ -> None
  }
}

fn compute_safety_factor(area: Area, robots: List(Robot)) -> Int {
  robots
  |> list.map(fn(robot) { robot.location })
  |> list.map(find_quadrant(area, _))
  |> list.filter(option.is_some)
  |> list.group(function.identity)
  |> dict.fold(1, fn(accum, _, value) { accum * list.length(value) })
}

fn iterate(init: a, f: fn(a) -> a, times: Int) -> a {
  case times > 0 {
    False -> init
    True -> iterate(f(init), f, times - 1)
  }
}

fn exact_midpoint(values: List(Int)) -> Option(Int) {
  case values {
    [] -> None
    [x] -> Some(x)
    _ -> {
      let sum = list.fold(values, 0, int.add)
      let len = list.length(values)
      let rem = sum % len
      case rem {
        0 -> Some(sum / len)
        _ -> None
      }
    }
  }
}

fn has_vertical_symmetry(points: List(Point)) -> Bool {
  points
  |> list.group(fn(point) { point.y })
  |> dict.to_list
  |> list.fold_until(None, fn(axis, entry) {
    // TODO something dodgy here. we're not computing the distribution around the
    // midpoint for one 
    let #(_, line) = entry
    case axis {
      None -> {
        case line {
          [] -> Continue(None)
          [Point(x, _)] -> Continue(Some(x))
          _ -> {
            let x = exact_midpoint(list.map(line, fn(point) { point.x }))
            case x {
              None -> Stop(None)
              _ -> Continue(x)
            }
          }
        }
      }
      Some(axis) -> {
        case line {
          [] -> Continue(Some(axis))
          [Point(x, _)] -> {
            case x == axis {
              True -> Continue(Some(axis))
              False -> Stop(None)
            }
          }
          _ -> {
            let x = exact_midpoint(list.map(line, fn(point) { point.x }))
            case x {
              Some(x) if x == axis -> Continue(Some(axis))
              _ -> Stop(None)
            }
          }
        }
      }
    }
  })
  |> option.is_some
}

fn render_area(area: Area, robots: List(Robot)) -> String {
  let points = robots |> list.map(fn(robot) { robot.location }) |> set.from_list
  list.range(0, area.height - 1)
  |> list.fold(string_tree.new(), fn(st, y) {
    list.range(0, area.width - 1)
    |> list.fold(st, fn(st, x) {
      let char = case set.contains(points, Point(x, y)) {
        True -> "#"
        False -> " "
      }
      string_tree.append(st, char)
    })
    |> string_tree.append("\n")
  })
  |> string_tree.to_string
}

fn find_present(
  area: Area,
  robots: List(Robot),
  times: Int,
) -> #(List(Robot), Int) {
  case has_vertical_symmetry(list.map(robots, fn(robot) { robot.location })) {
    True -> #(robots, times)
    False ->
      find_present(area, list.map(robots, move_robot(_, area)), times + 1)
  }
}

fn in_triangle(robots: List(Robot)) -> Bool {
  let points = list.map(robots, fn(robot) { robot.location }) |> set.from_list
  points
  |> set.to_list
  |> list.any(fn(point) {
    set.contains(points, Point(point.x - 1, point.y + 1))
    && set.contains(points, Point(point.x + 1, point.y + 1))
    && set.contains(points, Point(point.x - 2, point.y + 2))
    && set.contains(points, Point(point.x + 2, point.y + 2))
    && set.contains(points, Point(point.x - 3, point.y + 3))
    && set.contains(points, Point(point.x + 3, point.y + 3))
  })
}

fn move_robots(area: Area, robots: List(Robot)) -> List(Robot) {
  list.map(robots, move_robot(_, area))
}

fn yield_presents(
  area: Area,
  robots: List(Robot),
) -> Yielder(#(List(Robot), Int)) {
  let iterator = yielder.iterate(robots, move_robots(area, _))
  let indexed = yielder.index(iterator)
  yielder.filter(indexed, fn(entry) {
    let #(robots, _) = entry
    in_triangle(robots)
  })
}

pub fn main() {
  let path = "input.txt"
  let assert Ok(data) = simplifile.read(path)
  let robots = data |> string.split("\n") |> list.map(parse_robot)
  let area = Area(width: 101, height: 103, center: Point(50, 51))
  let later =
    iterate(robots, fn(robots) { list.map(robots, move_robot(_, area)) }, 100)
  let safety = compute_safety_factor(area, later)
  io.debug(safety)
  let maybe_presents = yield_presents(area, robots)
  yielder.each(maybe_presents, fn(entry) {
    let #(robots, i) = entry
    io.println(render_area(area, robots))
    io.println(int.to_string(i))
    io.println("")
  })
  io.println("Done")
}
