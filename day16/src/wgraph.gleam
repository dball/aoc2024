import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/order
import gleam/set.{type Set}

/// A directed graph of nodes indexed by ident.
pub type Graph(a) {
  Graph(nodes: Dict(a, Node(a)))
}

/// A node, characterized by its outgoing edges.
pub type Node(a) {
  Node(edges: Set(Edge(a)))
}

/// An edge is a weighed connection to an ident.
pub type Edge(a) {
  Edge(dest: a, weight: Int)
}

/// A path is a list of edges, where the head is the last transition.
pub type Path(a) {
  Path(
    edges: List(Edge(a)),
    total_cost: Int,
    estimated_remaining_cost: Int,
    estimated_total_cost: Int,
  )
}

/// Returns the list of all of the cheapest paths from the start to any of the
// ends in the graph.

pub fn find_cheapest_paths(
  graph: Graph(a),
  estimate_cost: fn(a) -> Int,
  start: a,
  ends: Set(a),
) -> List(Path(a)) {
  let estimated_total_cost = estimate_cost(start)
  let init =
    Path(
      edges: [Edge(start, 0)],
      total_cost: 0,
      estimated_remaining_cost: estimated_total_cost,
      estimated_total_cost: estimated_total_cost,
    )
  find_cheapest_paths_loop(graph, estimate_cost, ends, [init], [])
}

fn find_cheapest_paths_loop(
  graph: Graph(a),
  estimate_cost: fn(a) -> Int,
  ends: Set(a),
  candidates: List(Path(a)),
  solutions: List(Path(a)),
) -> List(Path(a)) {
  let solution = solutions |> list.first
  let candidates =
    case solution {
      // Discard candidates more expensive than our solution(s).
      Ok(solution) -> {
        list.filter(candidates, fn(path) {
          path.estimated_total_cost <= solution.total_cost
        })
      }
      Error(_) -> candidates
    }
    // Sort by least estimated cost
    |> list.sort(fn(a, b) {
      int.compare(a.estimated_total_cost, b.estimated_total_cost)
    })
  case candidates {
    // Whatever we got, we got.
    [] -> solutions
    [candidate, ..rest] -> {
      let assert Ok(last_edge) = list.first(candidate.edges)
      case set.contains(ends, last_edge.dest) {
        // Our candidate is a solution, figure out what to do with it
        True -> {
          let solutions = case solution {
            Ok(solution) -> {
              case int.compare(candidate.total_cost, solution.total_cost) {
                order.Lt -> [candidate]
                order.Eq -> [candidate, ..solutions]
                order.Gt -> solutions
              }
            }
            Error(_) -> [candidate]
          }
          find_cheapest_paths_loop(graph, estimate_cost, ends, rest, solutions)
        }
        // Our candidate is not a solution, project forwards
        False -> {
          let assert Ok(node) = dict.get(graph.nodes, last_edge.dest)
          let new_candidates =
            set.map(node.edges, fn(edge) {
              let estimated_remaining_cost = estimate_cost(edge.dest)
              let total_cost = edge.weight + candidate.total_cost
              let estimated_total_cost = estimated_remaining_cost + total_cost
              Path(
                edges: [edge, ..candidate.edges],
                total_cost: total_cost,
                estimated_remaining_cost: estimated_remaining_cost,
                estimated_total_cost: estimated_total_cost,
              )
            })
            |> set.to_list
          let candidates = list.flatten([new_candidates, candidates])
          find_cheapest_paths_loop(
            graph,
            estimate_cost,
            ends,
            candidates,
            solutions,
          )
        }
      }
    }
  }
}
