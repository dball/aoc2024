import edn
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/result
import gleam/set.{type Set}

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
  let q = graph.get_vertices() |> set.from_list
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
  q: Set(vertex),
) {
  let u =
    q
    |> set.to_list
    |> list.max(fn(v1, v2) {
      let dist_v1 = dict.get(dist, v1)
      let dist_v2 = dict.get(dist, v2)
      case dist_v1, dist_v2 {
        Error(_), Error(_) -> order.Eq
        Ok(_), Error(_) -> order.Gt
        Error(_), Ok(_) -> order.Lt
        Ok(dist_v1), Ok(dist_v2) -> int.compare(dist_v2, dist_v1)
      }
    })
  case u {
    Ok(u) -> {
      let q = q |> set.delete(u)
      let neighbors =
        graph.get_neighbors(u)
        |> dict.to_list
        |> list.filter(fn(entry) {
          let #(vertex, _) = entry
          set.contains(q, vertex)
        })
      let #(dist, prev) =
        list.fold(neighbors, #(dist, prev), fn(accum, entry) {
          let #(dist, prev) = accum
          let #(v, #(edge, weight)) = entry
          case dict.get(dist, u) {
            Ok(dist_u) -> {
              let alt = dist_u + weight
              let dist_v = dict.get(dist, v)
              case int.compare(alt, result.unwrap(dist_v, alt + 1)) {
                order.Lt -> #(
                  dist |> dict.insert(v, alt),
                  prev |> dict.insert(v, #(u, edge, weight)),
                )
                _ -> #(dist, prev)
              }
            }
            Error(_) -> #(dist, prev)
          }
        })
      compute_dist_prev(graph, dist, prev, q)
    }
    Error(_) -> #(dist, prev)
  }
}
