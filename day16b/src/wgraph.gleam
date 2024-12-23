import edn
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/order
import gleam/set.{type Set}
import priorityq.{type PriorityQueue}

pub type Graph(node, direction) {
  Graph(get_edges_from: fn(node, direction) -> Dict(direction, #(node, Int)))
}

pub type Visit(node, direction) {
  Visit(node: node, facing: direction, cost: Int)
}

pub type Path(node, direction) {
  Path(
    latest: Visit(node, direction),
    history: List(Visit(node, direction)),
    visited: Set(#(node, direction)),
    total_cost: Int,
    estimated_total_cost: Int,
  )
}

pub fn find_cheapest_paths(
  graph: Graph(node, direction),
  estimate_cost: fn(node, direction, node) -> Int,
  start: #(node, direction),
  end: node,
) -> List(Path(node, direction)) {
  let #(src, facing) = start
  let init =
    Path(
      latest: Visit(src, facing, 0),
      history: [],
      visited: set.new() |> set.insert(#(src, facing)),
      total_cost: 0,
      estimated_total_cost: estimate_cost(src, facing, end),
    )
  let candidates =
    priorityq.new(fn(a: Path(node, direction), b: Path(node, direction)) {
      int.compare(b.estimated_total_cost, a.estimated_total_cost)
    })
    |> priorityq.push(init)
  find_cheapest_paths_loop(graph, estimate_cost, end, candidates, [])
}

fn debug_pq(pq: PriorityQueue(Path(node, direction))) {
  edn.debug(#("pq", priorityq.size(pq), list.reverse(debug_pq_costs(pq, []))))
}

fn debug_pq_costs(
  pq: PriorityQueue(Path(node, direction)),
  accum: List(#(Int, Int)),
) -> List(#(Int, Int)) {
  case priorityq.peek(pq) {
    Some(path) -> {
      let accum = [#(path.estimated_total_cost, path.total_cost), ..accum]
      debug_pq_costs(priorityq.pop(pq), accum)
    }
    None -> accum
  }
}

fn find_cheapest_paths_loop(
  graph: Graph(node, direction),
  estimate_cost: fn(node, direction, node) -> Int,
  end: node,
  candidates: PriorityQueue(Path(node, direction)),
  solutions: List(Path(node, direction)),
) -> List(Path(node, direction)) {
  let solution_cost = case solutions {
    [solution, ..] -> Some(solution.total_cost)
    _ -> None
  }
  //debug_pq(candidates)
  case priorityq.peek(candidates), solution_cost {
    Some(candidate), Some(solution_cost)
      if candidate.estimated_total_cost > solution_cost
    -> {
      find_cheapest_paths_loop(
        graph,
        estimate_cost,
        end,
        priorityq.pop(candidates),
        solutions,
      )
    }
    None, _ -> {
      edn.debug(#("exhausted candidates"))
      solutions
    }
    Some(candidate), _ -> {
      let candidates = priorityq.pop(candidates)
      let #(candidates, solutions) = case
        candidate.latest.node == end,
        solution_cost
      {
        True, None -> {
          edn.debug(#("first solution"))
          #(candidates, [candidate])
        }
        True, Some(solution_cost) -> {
          edn.debug(#("new solution", candidate.total_cost, solution_cost))
          case int.compare(candidate.total_cost, solution_cost) {
            order.Lt -> #(candidates, [candidate])
            order.Eq -> #(candidates, [candidate, ..solutions])
            order.Gt -> #(candidates, solutions)
          }
        }
        False, _ -> {
          let edges =
            graph.get_edges_from(candidate.latest.node, candidate.latest.facing)
          let candidates =
            dict.fold(edges, candidates, fn(candidates, direction, entry) {
              let #(neighbor, weight) = entry
              let path =
                Path(
                  latest: Visit(neighbor, direction, weight),
                  history: [candidate.latest, ..candidate.history],
                  visited: set.insert(candidate.visited, #(neighbor, direction)),
                  total_cost: candidate.total_cost + weight,
                  estimated_total_cost: candidate.total_cost
                    + weight
                    + estimate_cost(neighbor, direction, end),
                )
              // TODO only if we're not looping, maybe?
              priorityq.push(candidates, path)
            })
          #(candidates, solutions)
        }
      }
      find_cheapest_paths_loop(graph, estimate_cost, end, candidates, solutions)
    }
  }
}
