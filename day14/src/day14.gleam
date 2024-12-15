import gleam/dict
import gleam/function
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regexp
import gleam/result
import gleam/string
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

pub fn main() {
  let path = "input.txt"
  let assert Ok(data) = simplifile.read(path)
  let robots = data |> string.split("\n") |> list.map(parse_robot)
  let area = Area(width: 101, height: 103, center: Point(50, 51))
  let later =
    iterate(robots, fn(robots) { list.map(robots, move_robot(_, area)) }, 100)
  let safety = compute_safety_factor(area, later)
  io.debug(safety)
  io.println("Done")
}
