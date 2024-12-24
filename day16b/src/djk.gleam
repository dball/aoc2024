import edn
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/result
import gleam/set.{type Set}
import gleamy/priority_queue as pq

/// Orders the weights from smallest to largest, treating None as positive infinity
fn weight_compare(a: Option(Int), b: Option(Int)) -> order.Order {
  case a, b {
    None, None -> order.Eq
    Some(_), None -> order.Lt
    None, Some(_) -> order.Gt
    Some(a), Some(b) -> int.compare(a, b)
  }
}

/// Orders the vertices from largest weight to smallest weight
fn vertex_compare(a: #(vertex, Int), b: #(vertex, Int)) -> order.Order {
  int.compare(b.1, a.1)
}

fn build_queue(init: vertex) -> pq.Queue(#(vertex, Int)) {
  pq.new(vertex_compare) |> pq.push(#(init, 0))
}

pub type Graph(vertex, edge) {
  Graph(
    get_vertices: fn() -> List(vertex),
    get_neighbors: fn(vertex) -> Dict(vertex, #(edge, Int)),
  )
}

pub type Path(vertex, edge) {
  Path(head: vertex, tail: List(#(vertex, edge)), cost: Int)
}

pub fn find_shortest_path(
  graph: Graph(vertex, edge),
  start: vertex,
  end: vertex,
) -> Option(Path(vertex, edge)) {
  let q = build_queue(start)
  let dist = dict.new() |> dict.insert(start, 0)
  let prev = dict.new()
  let #(dist, prev) = compute_dist_prev(graph, dist, prev, q)
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

fn compute_dist_prev(
  graph: Graph(vertex, edge),
  dist: Dict(vertex, Int),
  prev: Dict(vertex, #(vertex, edge, Int)),
  q: pq.Queue(#(vertex, Int)),
) {
  case pq.pop(q) {
    Ok(#(#(u, _), q)) -> {
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
      compute_dist_prev(graph, dist, prev, q)
    }
    Error(_) -> #(dist, prev)
  }
}
