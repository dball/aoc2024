import gleam/dict.{type Dict}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/set.{type Set}
import gleam/string
import grid.{type Direction, type Point, Point}
import simplifile

type Move {
  Forward
  TurnLeft
  TurnRight
}

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

type Path2 {
  Path2(
    head: Point,
    facing: Direction,
    cost_from_start: Int,
    estimated_total_cost: Int,
  )
}

// TODO also facing for a
fn cheapest_cost_between(a: Point, b: Point) -> Int {
  let dx = int.absolute_value(a.x - b.x)
  let dy = int.absolute_value(a.y - b.y)
  case dx, dy {
    0, y -> y
    x, 0 -> x
    x, y -> x + y + 1000
  }
}

fn find_cheapest_solution(maze: Maze) -> Option(Path2) {
  let path =
    Path2(maze.start, grid.E, 0, cheapest_cost_between(maze.start, maze.end))
  find_cheapest_solution_loop(maze, [path])
}

fn find_cheapest_solution_loop(
  maze: Maze,
  potentials: List(Path2),
) -> Option(Path2) {
  let sorted =
    potentials
    |> list.sort(fn(a, b) {
      int.compare(a.estimated_total_cost, b.estimated_total_cost)
    })
  case sorted {
    [] -> None
    [path, ..] if path.head == maze.end -> Some(path)
    [path, ..rest] -> {
      let neighbors =
        [
          {
            let point = grid.project(path.head, path.facing)
            Path2(
              point,
              path.facing,
              path.cost_from_start + 1,
              cheapest_cost_between(point, maze.end),
            )
          },
          {
            let facing = grid.turn(path.facing, grid.Left)
            let point = grid.project(path.head, facing)
            Path2(
              point,
              facing,
              path.cost_from_start + 1001,
              cheapest_cost_between(point, maze.end),
            )
          },
          {
            let facing = grid.turn(path.facing, grid.Right)
            let point = grid.project(path.head, facing)
            Path2(
              point,
              facing,
              path.cost_from_start + 1001,
              cheapest_cost_between(point, maze.end),
            )
          },
        ]
        |> list.filter(fn(path) { grid.has_contents(maze.rooms, path.head) })
      // TODO Concat rest and neighbors, removing for each point+facing all but the
      // cheapest cost_from_start
      find_cheapest_solution_loop(maze, list.flatten([neighbors, rest]))
    }
  }
}

type Path {
  Path(
    start: Point,
    end: Point,
    facing: Direction,
    moves: List(Move),
    visits: Set(Point),
  )
}

fn extend_path(maze: Maze, path: Path, point: Point) -> Option(Path) {
  let is_room = grid.has_contents(maze.rooms, point)
  case is_room && !set.contains(path.visits, point) {
    True ->
      Some(Path(..path, end: point, visits: set.insert(path.visits, point)))
    False -> None
  }
}

fn find_solutions_starting_with(maze: Maze, path: Path) -> List(Path) {
  case path.end == maze.end {
    True -> [path]
    False -> {
      let moves = [Forward, TurnLeft, TurnRight]
      let next_paths =
        list.fold(moves, [], fn(paths, move) {
          case move {
            Forward -> {
              let next_point = grid.project(path.end, path.facing)
              case extend_path(maze, path, next_point) {
                None -> paths
                Some(path) -> [
                  Path(..path, moves: [move, ..path.moves]),
                  ..paths
                ]
              }
            }
            TurnLeft | TurnRight -> {
              let turn = case move {
                TurnLeft -> grid.Left
                _ -> grid.Right
              }
              let next_facing = grid.turn(path.facing, turn)
              let next_point = grid.project(path.end, next_facing)
              case extend_path(maze, path, next_point) {
                None -> paths
                Some(path) -> [
                  Path(
                    ..path,
                    facing: next_facing,
                    moves: [Forward, move, ..path.moves],
                  ),
                  ..paths
                ]
              }
            }
          }
        })
      list.flat_map(next_paths, find_solutions_starting_with(maze, _))
    }
  }
}

fn find_solutions(maze: Maze) -> List(Path) {
  let path =
    Path(
      start: maze.start,
      end: maze.start,
      facing: grid.E,
      moves: [],
      visits: set.new() |> set.insert(maze.start),
    )
  find_solutions_starting_with(maze, path)
  |> list.map(fn(path) { Path(..path, moves: list.reverse(path.moves)) })
}

fn move_score(move: Move) {
  case move {
    Forward -> 1
    _ -> 1000
  }
}

fn compute_score(path: Path) -> Int {
  list.map(path.moves, move_score) |> list.fold(0, int.add)
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
