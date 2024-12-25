import edn
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/result
import gleam/set.{type Set}
import gleamy/priority_queue as pq

/// Orders the vertices from least weight to greatest weight
fn vertex_compare(a: #(vertex, Int), b: #(vertex, Int)) -> order.Order {
  int.compare(a.1, b.1)
}

/// A graph links vertices via edges
pub type Graph(vertex, edge) {
  /// A graph is defined by a functional contract
  Graph(
    get_vertices: fn() -> List(vertex),
    get_neighbors: fn(vertex) -> Dict(vertex, #(edge, Int)),
  )
}

/// A path is a sequence of vertices linked by edges, with its cost the sum of
/// the edges' weights
pub type Path(vertex, edge) {
  Path(head: vertex, tail: List(#(vertex, edge)), cost: Int)
}

fn path_compare(a: Path(vertex, edge), b: Path(vertex, edge)) -> order.Order {
  order.break_tie(
    int.compare(a.cost, b.cost),
    int.compare(list.length(a.tail), list.length(b.tail)),
  )
}

/// Returns a shortest path from the start to the end, if there is at least one.
pub fn find_shortest_path(
  graph: Graph(vertex, edge),
  start: vertex,
  end: vertex,
) -> Option(Path(vertex, edge)) {
  let q = pq.new(vertex_compare) |> pq.push(#(start, 0))
  let dist = dict.new() |> dict.insert(start, 0)
  let prev = dict.new()
  let ends = set.new() |> set.insert(end)
  let #(_dist, prev) = compute_dist_prev_until(graph, ends, dist, prev, q)
  compute_shortest_path(prev, start, Path(end, [], 0))
}

fn compute_shortest_path(
  prev: Dict(vertex, #(vertex, edge, Int)),
  start: vertex,
  path: Path(vertex, edge),
) -> Option(Path(vertex, edge)) {
  case path.head == start {
    True -> Some(path)
    False -> {
      case dict.get(prev, path.head) {
        Ok(#(head, edge, weight)) -> {
          let path =
            Path(
              head: head,
              tail: [#(path.head, edge), ..path.tail],
              cost: weight + path.cost,
            )
          compute_shortest_path(prev, start, path)
        }
        Error(_) -> None
      }
    }
  }
}

// TODO allow set of prev values for a key (multiple ways to arrive at the index vertex)
fn compute_dist_prev_until(
  graph: Graph(vertex, edge),
  ends: Set(vertex),
  dist: Dict(vertex, Int),
  prev: Dict(vertex, #(vertex, edge, Int)),
  q: pq.Queue(#(vertex, Int)),
) {
  case set.size(ends) {
    0 -> #(dist, prev)
    _ -> {
      case pq.pop(q) {
        Ok(#(#(u, _), q)) -> {
          let ends = case set.contains(ends, u) {
            True -> ends |> set.delete(u)
            False -> ends
          }
          let neighbors = graph.get_neighbors(u) |> dict.to_list
          let #(dist, prev, q) =
            list.fold(neighbors, #(dist, prev, q), fn(accum, entry) {
              let #(dist, prev, q) = accum
              let #(v, #(edge, weight)) = entry
              case dict.get(dist, u) {
                Ok(dist_u) -> {
                  let alt = dist_u + weight
                  let dist_v = dict.get(dist, v)
                  case int.compare(alt, result.unwrap(dist_v, alt + 1)) {
                    order.Lt -> {
                      #(
                        dist |> dict.insert(v, alt),
                        prev |> dict.insert(v, #(u, edge, weight)),
                        q |> pq.push(#(v, alt)),
                      )
                    }
                    _ -> #(dist, prev, q)
                  }
                }
                Error(_) -> #(dist, prev, q)
              }
            })
          compute_dist_prev_until(graph, ends, dist, prev, q)
        }
        Error(_) -> #(dist, prev)
      }
    }
  }
}
