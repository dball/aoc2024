import edn
import gleam/dict.{type Dict}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/set
import grid.{type Direction, type Grid, type Point, Grid, Point}
import priorityq
import simplifile
import wgraph

type Room {
  Start
  End
  Hall
}

type Maze {
  Maze(start: Point, end: Point, rooms: Grid(Room))
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
  let rooms = grid.parse_grid(input, parse)
  let assert [#(start, _)] =
    rooms.contents
    |> dict.filter(fn(_, room) {
      case room {
        Start -> True
        _ -> False
      }
    })
    |> dict.to_list
  let assert [#(end, _)] =
    rooms.contents
    |> dict.filter(fn(_, room) {
      case room {
        End -> True
        _ -> False
      }
    })
    |> dict.to_list
  Maze(start, end, rooms)
}

fn render_maze(maze: Maze) -> String {
  grid.render_grid(maze.rooms, fn(contents) {
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
  maze.rooms.contents
  |> dict.keys
  |> list.filter(fn(point) { deadend_neighbor(maze, point) |> option.is_some })
}

/// Fills in the point if it is a deadend, and recurses to the neighbor.
fn fill_deadend(maze: Maze, point: Point) -> Maze {
  case deadend_neighbor(maze, point) {
    Some(neighbor) -> {
      let contents = dict.delete(maze.rooms.contents, point)
      let rooms = Grid(..maze.rooms, contents: contents)
      let maze = Maze(..maze, rooms: rooms)
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

fn build_wgraph(maze: Maze) -> wgraph.Graph(Point, Direction) {
  wgraph.Graph(get_edges_from: fn(src, facing) {
    grid.directions
    |> list.map(fn(direction) {
      let dest = grid.project(src, direction)
      let neighbor = grid.get_content(maze.rooms, dest)
      #(direction, dest, neighbor)
    })
    |> list.fold(dict.new(), fn(accum, entry) {
      let #(direction, dest, neighbor) = entry
      case neighbor {
        Some(_) -> {
          let weight = case facing == direction {
            True -> Some(1)
            False -> {
              case facing == grid.opposite(direction) {
                True -> None
                False -> Some(1001)
              }
            }
          }
          case weight {
            None -> accum
            Some(weight) -> dict.insert(accum, direction, #(dest, weight))
          }
        }
        None -> accum
      }
    })
  })
}

fn find_cheapest_wgraph_paths(maze: Maze) -> List(wgraph.Path(Point, Direction)) {
  wgraph.find_cheapest_paths(
    build_wgraph(maze),
    fn(src, facing, dest) { cheapest_cost_between(facing, src, dest) },
    #(maze.start, grid.E),
    maze.end,
  )
}

pub fn main() {
  let path = "input.txt"
  let assert Ok(data) = simplifile.read(path)
  let maze = parse_input(data)
  let maze = fill_deadends(maze)
  io.println(render_maze(maze))
  let solutions = find_cheapest_wgraph_paths(maze)
  edn.debug(list.length(solutions))
  edn.debug(list.map(solutions, fn(solution) { solution.total_cost }))
  io.println("Done")
}
