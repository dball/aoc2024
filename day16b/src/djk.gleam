import gleam/dict.{type Dict}
import gleam/int
import gleam/list
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
) -> List(vertex) {
  let q = graph.get_vertices() |> set.from_list
  let dist = dict.new() |> dict.insert(start, 0)
  let prev = dict.new()
  let #(_dist, prev) = compute_dist_prev(graph, dist, prev, q)
  compute_shortest_path(prev, start, [end])
}

fn compute_shortest_path(
  prev: Dict(vertex, vertex),
  start: vertex,
  path: List(vertex),
) -> List(vertex) {
  case path {
    [head, ..] if head == start -> path
    [head, ..] -> {
      case dict.get(prev, head) {
        Ok(head) -> compute_shortest_path(prev, start, [head, ..path])
        Error(_) -> []
      }
    }
    [] -> []
  }
}

fn compute_dist_prev(
  graph: Graph(vertex, edge),
  dist: Dict(vertex, Int),
  prev: Dict(vertex, vertex),
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
          let #(v, #(_edge, weight)) = entry
          let assert Ok(dist_u) = dict.get(dist, u)
          let alt = dist_u + weight
          let dist_v = dict.get(dist, v)
          case int.compare(alt, result.unwrap(dist_v, alt + 1)) {
            order.Lt -> #(
              dist |> dict.insert(v, alt),
              prev |> dict.insert(v, u),
            )
            _ -> #(dist, prev)
          }
        })
      compute_dist_prev(graph, dist, prev, q)
    }
    Error(_) -> #(dist, prev)
  }
}
