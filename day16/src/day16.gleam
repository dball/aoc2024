import gleam/dict.{type Dict}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import grid.{type Direction, type Point, Point}
import simplifile

type Room {
  Start
  End
  Hall
}

type Maze {
  Maze(start: Point, end: Point, rooms: Dict(Point, Room), max: Point)
}

fn parse_input(input: String) -> Maze {
  let parse = fn(char: String) {
    case char {
      "." -> Some(Hall)
      "S" -> Some(Start)
      "E" -> Some(End)
      _ -> None
    }
  }
  let #(rooms, max) = grid.parse_grid(input, parse)
  let assert [#(start, _)] =
    rooms
    |> dict.filter(fn(_, room) {
      case room {
        Start -> True
        _ -> False
      }
    })
    |> dict.to_list
  let assert [#(end, _)] =
    rooms
    |> dict.filter(fn(_, room) {
      case room {
        End -> True
        _ -> False
      }
    })
    |> dict.to_list
  Maze(start, end, rooms, max)
}

fn render_maze(maze: Maze) -> String {
  grid.render_grid(maze.rooms, maze.max, fn(contents) {
    case contents {
      Some(Start) -> "S"
      Some(End) -> "E"
      Some(Hall) -> "."
      None -> "#"
    }
  })
}

/// If the point is a hall with only one neighbor, this returns
/// that neighbor's point.
fn deadend_neighbor(maze: Maze, point: Point) -> Option(Point) {
  case grid.get_content(maze.rooms, point) {
    Some(Hall) -> {
      let rooms = grid.get_neighboring_contents(maze.rooms, point)
      case rooms {
        [neighbor] -> Some(neighbor.0)
        _ -> None
      }
    }
    _ -> None
  }
}

/// Returns the list of all deadends in the maze.
fn find_deadends(maze: Maze) -> List(Point) {
  maze.rooms
  |> dict.keys
  |> list.filter(fn(point) { deadend_neighbor(maze, point) |> option.is_some })
}

/// Fills in the point if it is a deadend, and recurses to the neighbor.
fn fill_deadend(maze: Maze, point: Point) -> Maze {
  case deadend_neighbor(maze, point) {
    Some(neighbor) -> {
      let maze = Maze(..maze, rooms: dict.delete(maze.rooms, point))
      fill_deadend(maze, neighbor)
    }
    _ -> {
      maze
    }
  }
}

fn fill_deadends(maze: Maze) -> Maze {
  find_deadends(maze)
  |> list.fold(maze, fn(maze, deadend) { fill_deadend(maze, deadend) })
}

type Path {
  Path(
    head: Point,
    facing: Direction,
    cost_from_start: Int,
    estimated_total_cost: Int,
  )
}

fn cheapest_cost_between(facing: Direction, a: Point, b: Point) -> Int {
  let d = Point(b.x - a.x, b.y - a.y)
  let turns = case facing, d.x, d.y {
    _, 0, 0 -> 0
    grid.E, 0, _ | grid.W, 0, _ | grid.N, _, 0 | grid.S, _, 0 -> 1
    grid.E, dx, 0 if dx > 0 -> 0
    grid.W, dx, 0 if dx < 0 -> 0
    grid.N, 0, dy if dy < 0 -> 0
    grid.S, 0, dy if dy > 0 -> 0
    _, _, _ -> 2
  }
  turns * 1000 + int.absolute_value(d.x) + int.absolute_value(d.y)
}

fn find_cheapest_solution(maze: Maze) -> Option(Path) {
  let path =
    Path(
      maze.start,
      grid.E,
      0,
      cheapest_cost_between(grid.E, maze.start, maze.end),
    )
  find_cheapest_solution_loop(maze, dict.new() |> dict.insert(maze.start, path))
}

fn find_cheapest_solution_loop(
  maze: Maze,
  potentials: Dict(Point, Path),
) -> Option(Path) {
  let sorted =
    potentials
    |> dict.to_list
    |> list.sort(fn(a, b) {
      int.compare({ a.1 }.estimated_total_cost, { b.1 }.estimated_total_cost)
    })
  io.debug(#("sorted", sorted))
  case sorted {
    [] -> None
    [#(_, path), ..] if path.head == maze.end -> Some(path)
    [#(_, path), ..rest] -> {
      io.debug(#("visiting", path))
      [
        {
          let point = grid.project(path.head, path.facing)
          Path(
            point,
            path.facing,
            path.cost_from_start + 1,
            cheapest_cost_between(path.facing, point, maze.end),
          )
        },
        {
          let facing = grid.turn(path.facing, grid.Left)
          let point = grid.project(path.head, facing)
          Path(
            point,
            facing,
            path.cost_from_start + 1001,
            cheapest_cost_between(facing, point, maze.end),
          )
        },
        {
          let facing = grid.turn(path.facing, grid.Right)
          let point = grid.project(path.head, facing)
          Path(
            point,
            facing,
            path.cost_from_start + 1001,
            cheapest_cost_between(facing, point, maze.end),
          )
        },
      ]
      |> list.filter(fn(path) { grid.has_contents(maze.rooms, path.head) })
      |> list.fold(rest |> dict.from_list, fn(potentials, path) {
        case dict.get(potentials, path.head) {
          Ok(path2) -> {
            case path.cost_from_start < path2.cost_from_start {
              True -> dict.insert(potentials, path.head, path)
              False -> potentials
            }
          }
          Error(_) -> dict.insert(potentials, path.head, path)
        }
      })
      |> find_cheapest_solution_loop(maze, _)
    }
  }
}

pub fn main() {
  let path = "input0.txt"
  let assert Ok(data) = simplifile.read(path)
  let maze = parse_input(data)
  io.println(render_maze(maze))
  let maze = fill_deadends(maze)
  io.println(render_maze(maze))
  io.debug(find_cheapest_solution(maze))
  //let solutions = find_solutions(maze)
  //let min = solutions |> list.map(compute_score) |> list.fold(-1, int.min)
  //io.println(int.to_string(min))
  io.println("Done")
}
