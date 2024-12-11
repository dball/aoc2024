import gleam/dict.{type Dict}
import gleam/int
import gleam/io
import gleam/list
import gleam/set
import gleam/string
import simplifile

type Point {
  Point(x: Int, y: Int)
}

type Node {
  Node(x: Int, y: Int, z: Int, ups: List(Point), downs: List(Point))
}

type Topomap {
  Topomap(nodes: Dict(Point, Node), min: Int, max: Int)
}

fn parse_topomap(s: String) -> Topomap {
  let lines = string.split(s, "\n")
  let nodes =
    list.index_fold(lines, dict.new(), fn(nodes, line, y) {
      let chars = string.to_graphemes(line)
      list.index_fold(chars, nodes, fn(nodes, char, x) {
        let assert Ok(z) = int.parse(char)
        dict.insert(nodes, Point(x, y), Node(x, y, z, [], []))
      })
    })
  Topomap(nodes, 0, 9)
}

fn read_node(topomap: Topomap, point: Point) -> Result(Node, Nil) {
  dict.get(topomap.nodes, point)
}

fn build_paths(topomap: Topomap) -> Topomap {
  let nodes =
    dict.map_values(topomap.nodes, fn(point, node) {
      let east = Point(..point, x: point.x + 1)
      let south = Point(..point, y: point.y + 1)
      let west = Point(..point, x: point.x - 1)
      let north = Point(..point, y: point.y - 1)
      [east, south, west, north]
      |> list.fold(node, fn(node, neighbor) {
        case read_node(topomap, neighbor) {
          Ok(nn) if nn.z - 1 == node.z ->
            Node(..node, ups: [Point(nn.x, nn.y), ..node.ups])
          Ok(nn) if nn.z + 1 == node.z ->
            Node(..node, downs: [Point(nn.x, nn.y), ..node.downs])
          _ -> node
        }
      })
    })
  Topomap(..topomap, nodes: nodes)
}

fn find_trailheads(topomap: Topomap) -> List(Node) {
  dict.fold(topomap.nodes, [], fn(trailheads, _, node) {
    case node.z {
      0 -> [node, ..trailheads]
      _ -> trailheads
    }
  })
}

fn find_climbs(topomap: Topomap, progress: List(Node)) -> List(List(Node)) {
  case progress {
    [] -> {
      find_trailheads(topomap)
      |> list.flat_map(fn(trailhead) { find_climbs(topomap, [trailhead]) })
    }
    [last, ..] if last.z == topomap.max -> [progress]
    [last, ..] -> {
      list.flat_map(last.ups, fn(up) {
        let assert Ok(climb) = read_node(topomap, up)
        find_climbs(topomap, [climb, ..progress])
      })
    }
  }
}

pub fn main() {
  let path = "input.txt"
  let assert Ok(data) = simplifile.read(path)
  let topomap = parse_topomap(data)
  let topomap = build_paths(topomap)

  let trailheads = find_trailheads(topomap)
  let scores =
    trailheads
    |> list.map(fn(trailhead) {
      let climbs = find_climbs(topomap, [trailhead])
      let peaks =
        climbs
        |> list.map(fn(nodes) {
          let assert Ok(peak) = list.first(nodes)
          peak
        })
        |> set.from_list
      set.size(peaks)
    })

  io.debug(scores)
  let total = list.fold(scores, 0, int.add)
  io.debug(total)

  let ratings =
    trailheads
    |> list.map(fn(trailhead) {
      let climbs = find_climbs(topomap, [trailhead])
      list.length(climbs)
    })
  let total = list.fold(ratings, 0, int.add)
  io.debug(total)
  io.println("Done")
}
