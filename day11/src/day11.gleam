import gleam/dict.{type Dict}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/regexp
import gleam/string
import simplifile

fn parse_data(s: String) -> List(String) {
  string.split(s, " ")
}

fn compute_next(engraving: String) -> List(String) {
  let assert Ok(re) = regexp.from_string("^0*(?=\\d)")
  case engraving {
    "0" -> ["1"]
    _ -> {
      let n = string.length(engraving)
      case int.is_even(n) {
        True -> {
          let half = n / 2
          [
            string.drop_end(engraving, half),
            string.drop_start(engraving, half) |> regexp.replace(re, _, ""),
          ]
        }
        False -> {
          let assert Ok(number) = int.parse(engraving)
          [int.to_string(number * 2024)]
        }
      }
    }
  }
}

type Node {
  Node(instances: Int, next: List(String))
}

type Graph {
  Graph(stones: Dict(String, Node))
}

fn build_graph(stones: List(String)) -> Graph {
  Graph(
    list.fold(stones, dict.new(), fn(stones, engraving) {
      dict.upsert(stones, engraving, fn(node) {
        case node {
          None -> Node(1, compute_next(engraving))
          Some(node) -> Node(..node, instances: node.instances + 1)
        }
      })
    }),
  )
}

fn blink_graph(graph: Graph) -> Graph {
  let blank_slate =
    dict.map_values(graph.stones, fn(_, node) { Node(..node, instances: 0) })
  Graph(
    list.fold(dict.values(graph.stones), blank_slate, fn(stones, node) {
      list.fold(node.next, stones, fn(stones, next_engraving) {
        dict.upsert(stones, next_engraving, fn(next_node) {
          case next_node {
            None ->
              Node(
                instances: node.instances,
                next: compute_next(next_engraving),
              )
            Some(extant_node) ->
              Node(
                ..extant_node,
                instances: extant_node.instances + node.instances,
              )
          }
        })
      })
    }),
  )
}

fn blink_graph_repeatedly(graph: Graph, times: Int) -> Graph {
  case times > 0 {
    True -> blink_graph_repeatedly(blink_graph(graph), times - 1)
    False -> graph
  }
}

fn count_stones(graph: Graph) -> Int {
  list.fold(dict.values(graph.stones), 0, fn(count, node) {
    count + node.instances
  })
}

pub fn main() {
  let path = "input.txt"
  let assert Ok(data) = simplifile.read(path)
  let stones = parse_data(data)
  let graph = build_graph(stones) |> blink_graph_repeatedly(75)
  io.debug(count_stones(graph))
  io.println("Done")
}
