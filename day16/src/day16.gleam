import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/set.{type Set}
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
    N -> Point(..point, y: point.y - 1)
    S -> Point(..point, y: point.y + 1)
    E -> Point(..point, x: point.x + 1)
    W -> Point(..point, x: point.x - 1)
  }
}

type Move {
  Forward
  TurnLeft
  TurnRight
}

fn turn(direction: Direction, move: Move) -> Direction {
  case move {
    Forward -> direction
    TurnLeft ->
      case direction {
        N -> W
        S -> E
        E -> N
        W -> S
      }
    TurnRight ->
      case direction {
        N -> E
        S -> W
        E -> S
        W -> N
      }
  }
}

type Maze {
  Maze(start: Point, end: Point, walls: Set(Point))
}

fn parse_input(input: String) -> Maze {
  let maze = Maze(Point(-1, -1), Point(-1, -1), walls: set.new())
  let lines = string.split(input, "\n")
  list.index_fold(lines, maze, fn(maze, line, y) {
    let chars = string.to_graphemes(line)
    list.index_fold(chars, maze, fn(maze, char, x) {
      let point = Point(x, y)
      case char {
        "#" -> Maze(..maze, walls: set.insert(maze.walls, point))
        "E" -> Maze(..maze, end: point)
        "S" -> Maze(..maze, start: point)
        _ -> maze
      }
    })
  })
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
  case set.contains(maze.walls, point) || set.contains(path.visits, point) {
    True -> None
    False ->
      Some(Path(..path, end: point, visits: set.insert(path.visits, point)))
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
              let next_point = project(path.end, path.facing)
              case extend_path(maze, path, next_point) {
                None -> paths
                Some(path) -> [
                  Path(..path, moves: [move, ..path.moves]),
                  ..paths
                ]
              }
            }
            TurnLeft | TurnRight -> {
              let next_facing = turn(path.facing, move)
              let next_point = project(path.end, next_facing)
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
      facing: E,
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
  let path = "input.txt"
  let assert Ok(data) = simplifile.read(path)
  let maze = parse_input(data)
  let solutions = find_solutions(maze)
  let assert Ok(min) =
    solutions |> list.map(compute_score) |> list.reduce(int.min)
  io.println(int.to_string(min))
}
