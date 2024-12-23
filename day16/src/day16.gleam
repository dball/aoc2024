import edn
import gleam/dict.{type Dict}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/set
import grid.{type Direction, type Point, Point}
import simplifile
import wgraph
import wgraph2

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

// TODO accumulate the set of points visited
type Path {
  Path(
    head: Point,
    facing: Direction,
    cost_from_start: Int,
    estimated_remaining_cost: Int,
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

fn estimate_total_cost(path: Path) -> Int {
  path.cost_from_start + path.estimated_remaining_cost
}

fn find_cheapest_solutions(maze: Maze) -> List(Path) {
  let path =
    Path(
      maze.start,
      grid.E,
      0,
      cheapest_cost_between(grid.E, maze.start, maze.end),
    )
  find_cheapest_solutions_loop(
    maze,
    dict.new() |> dict.insert(#(maze.start, grid.E), path),
    [],
  )
}

// TODO accumulate all instances of the cheapest solutions
fn find_cheapest_solutions_loop(
  maze: Maze,
  potentials: Dict(#(Point, Direction), Path),
  cheapests: List(Path),
) -> List(Path) {
  // TODO if we have any cheapests, discard anything projected to be more expensive
  let sorted =
    potentials
    |> dict.to_list
    |> list.filter(fn(entry) {
      let #(_, path) = entry
      case cheapests |> list.first {
        Ok(cheapest) -> {
          io.debug(#("cheapest", cheapest, "other", path))
          path.cost_from_start <= cheapest.cost_from_start
        }
        Error(_) -> True
      }
    })
    |> list.sort(fn(a, b) {
      int.compare(estimate_total_cost(a.1), estimate_total_cost(b.1))
    })
  case sorted {
    [] -> cheapests
    [#(_, path), ..rest] if path.head == maze.end -> {
      let next_cheapests = case cheapests {
        [] -> {
          io.debug(#("found first cheapest", path))
          [path]
        }
        [cheapest, ..] if path.cost_from_start < cheapest.cost_from_start -> {
          io.debug(#("found new cheapest", path))
          [path]
        }
        [cheapest, ..] if path.cost_from_start == cheapest.cost_from_start -> {
          io.debug(#("found equal cheapest", path))
          [path, ..cheapests]
        }
        _ -> {
          io.debug(#("ugh found weird cheapest", path))
          cheapests
        }
      }
      find_cheapest_solutions_loop(maze, rest |> dict.from_list, next_cheapests)
    }
    [#(_, path), ..rest] -> {
      io.debug(#("visit", path))
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
        case dict.get(potentials, #(path.head, path.facing)) {
          Ok(path2) -> {
            case path.cost_from_start < path2.cost_from_start {
              True -> dict.insert(potentials, #(path.head, path.facing), path)
              False -> potentials
            }
          }
          Error(_) -> dict.insert(potentials, #(path.head, path.facing), path)
        }
      })
      |> find_cheapest_solutions_loop(maze, _, cheapests)
    }
  }
}

fn build_graph(maze: Maze) -> wgraph.Graph(#(Point, Direction)) {
  let graph =
    dict.fold(maze.rooms, wgraph.Graph(nodes: dict.new()), fn(graph, point, _) {
      list.fold(grid.directions, graph, fn(graph, direction) {
        wgraph.Graph(nodes: dict.insert(
          graph.nodes,
          #(point, direction),
          wgraph.Node(edges: set.new()),
        ))
      })
    })
  dict.fold(maze.rooms, graph, fn(graph, point, _) {
    let neighbors =
      list.fold(grid.directions, dict.new(), fn(neighbors, direction) {
        let neighbor = grid.project(point, direction)
        case grid.get_content(maze.rooms, neighbor) {
          Some(_) -> dict.insert(neighbors, direction, neighbor)
          None -> neighbors
        }
      })
    list.fold(grid.directions, graph, fn(graph, to) {
      case dict.get(neighbors, to) {
        Ok(dest) -> {
          list.fold(grid.directions, graph, fn(graph, from) {
            let weight = case from == to {
              True -> 1
              False -> {
                case from == grid.opposite(to) {
                  True -> 0
                  False -> 1001
                }
              }
            }
            case weight {
              0 -> graph
              _ -> {
                let from_ident = #(point, from)
                let to_ident = #(dest, grid.opposite(to))
                let edge = wgraph.Edge(to_ident, weight)
                let node = dict.get(graph.nodes, from_ident)
                case node {
                  Ok(node) -> {
                    let edges = set.insert(node.edges, edge)
                    let node = wgraph.Node(edges)
                    wgraph.Graph(dict.insert(graph.nodes, from_ident, node))
                  }
                  Error(_) -> graph
                }
              }
            }
          })
        }
        Error(_) -> graph
      }
    })
  })
}

fn find_cheapest_graph_paths(maze: Maze) {
  let graph = build_graph(maze)
  let start = #(maze.start, grid.E)
  let ends =
    grid.directions
    |> list.map(fn(direction) { #(maze.end, direction) })
    |> set.from_list
  let estimate_cost = fn(ident) {
    let #(point, direction) = ident
    cheapest_cost_between(direction, point, maze.end)
  }
  wgraph.find_cheapest_paths(graph, estimate_cost, start, ends)
}

fn build_wgraph2(maze: Maze) -> wgraph2.Graph(Point, Direction) {
  wgraph2.Graph(get_edges_from: fn(src, facing) {
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

fn find_cheapest_wgraph_paths(
  maze: Maze,
) -> List(wgraph2.Path(Point, Direction)) {
  wgraph2.find_cheapest_paths(
    build_wgraph2(maze),
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
  solutions
  |> list.map(fn(solution) { edn.debug(list.first(solution)) })
  let best_seats =
    list.flat_map(solutions, fn(solution) {
      list.map(solution, fn(visit) { visit.node })
    })
    |> set.from_list
  edn.debug(set.size(best_seats))
  io.println("Done")
}
