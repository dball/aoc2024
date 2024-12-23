import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/order

pub type Graph(node, direction) {
  Graph(get_edges_from: fn(node, direction) -> Dict(direction, #(node, Int)))
}

pub type Visit(node, direction) {
  Visit(node: node, facing: direction, total_cost: Int)
}

pub type Path(node, direction) =
  List(Visit(node, direction))

pub fn find_cheapest_paths(
  graph: Graph(node, direction),
  estimate_cost: fn(node, direction, node) -> Int,
  start: #(node, direction),
  end: node,
) -> List(Path(node, direction)) {
  let #(src, facing) = start
  find_cheapest_paths_loop(
    graph,
    estimate_cost,
    end,
    [[Visit(src, facing, 0)]],
    [],
  )
}

fn find_cheapest_paths_loop(
  graph: Graph(node, direction),
  estimate_cost: fn(node, direction, node) -> Int,
  end: node,
  candidates: List(Path(node, direction)),
  solutions: List(Path(node, direction)),
) -> List(Path(node, direction)) {
  let solution_cost = case solutions {
    [[first, ..], ..] -> Some(first.total_cost)
    _ -> None
  }
  let candidates =
    case solution_cost {
      Some(solution_cost) -> {
        list.filter(candidates, fn(path) {
          let assert Ok(last) = list.first(path)
          last.total_cost <= solution_cost
        })
      }
      None -> candidates
    }
    |> list.sort(fn(a, b) {
      let assert Ok(alast) = list.first(a)
      let assert Ok(blast) = list.first(b)
      let acost =
        alast.total_cost + estimate_cost(alast.node, alast.facing, end)
      let bcost =
        blast.total_cost + estimate_cost(blast.node, blast.facing, end)
      int.compare(acost, bcost)
    })
  case candidates {
    [] -> solutions
    [candidate, ..rest] -> {
      let assert Ok(last) = list.first(candidate)
      let #(candidates, solutions) = case last.node == end, solution_cost {
        True, None -> #(rest, [candidate])
        True, Some(solution_cost) -> {
          case int.compare(last.total_cost, solution_cost) {
            order.Lt -> #(rest, [candidate])
            order.Eq -> #(rest, [candidate, ..solutions])
            order.Gt -> #(rest, solutions)
          }
        }
        False, _ -> {
          let edges = graph.get_edges_from(last.node, last.facing)
          let candidates =
            dict.fold(edges, rest, fn(candidates, direction, entry) {
              let #(neighbor, weight) = entry
              let visit = Visit(neighbor, direction, last.total_cost + weight)
              let path = [visit, ..candidate]
              [path, ..candidates]
            })
          #(candidates, solutions)
        }
      }
      find_cheapest_paths_loop(graph, estimate_cost, end, candidates, solutions)
    }
  }
}
