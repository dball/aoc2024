import gleam/dict.{type Dict}
import gleam/int
import gleam/io
import gleam/list.{Continue, Stop}
import gleam/option.{type Option, None, Some}
import gleam/string
import simplifile

type Disk {
  Disk(sectors: Dict(Int, Option(Int)))
}

fn fill_sectors(
  disk: Disk,
  offset: Int,
  length: Int,
  value: Option(Int),
) -> Disk {
  case length {
    0 -> disk
    _ -> {
      let sectors = dict.insert(disk.sectors, offset, value)
      fill_sectors(Disk(sectors: sectors), offset + 1, length - 1, value)
    }
  }
}

fn parse_disk_map(s: String) -> Disk {
  list.index_fold(
    string.to_graphemes(s),
    #(Disk(sectors: dict.new()), 0, 0),
    fn(accum, digit, i) {
      let #(disk, next_id, next_sector) = accum
      let assert Ok(length) = int.parse(digit)
      case i % 2 {
        0 -> {
          let disk = fill_sectors(disk, next_sector, length, Some(next_id))
          #(disk, next_id + 1, next_sector + length)
        }
        _ -> {
          let disk = fill_sectors(disk, next_sector, length, None)
          #(disk, next_id, next_sector + length)
        }
      }
    },
  ).0
}

fn swap_sectors(disk: Disk, i: Int, j: Int) -> Disk {
  let Disk(sectors) = disk
  let assert Ok(x) = dict.get(sectors, i)
  let assert Ok(y) = dict.get(sectors, j)
  let sectors = sectors |> dict.insert(i, y) |> dict.insert(j, x)
  Disk(sectors: sectors)
}

fn compact_disk(disk: Disk) -> Disk {
  let Disk(sectors) = disk
  let empty_sectors =
    dict.keys(sectors)
    |> list.filter(fn(sector) {
      let assert Ok(value) = dict.get(sectors, sector)
      option.is_none(value)
    })
    |> list.sort(int.compare)
  let file_sectors =
    dict.keys(sectors)
    |> list.filter(fn(sector) {
      let assert Ok(value) = dict.get(sectors, sector)
      option.is_some(value)
    })
    |> list.sort(int.compare)
    |> list.reverse()
  compact_disk_loop(disk, empty_sectors, file_sectors)
}

fn compact_disk_loop(
  disk: Disk,
  empty_sectors: List(Int),
  file_sectors: List(Int),
) -> Disk {
  case empty_sectors, file_sectors {
    [empty, ..empty_rest], [file, ..file_rest] if empty < file -> {
      compact_disk_loop(swap_sectors(disk, empty, file), empty_rest, file_rest)
    }
    _, _ -> disk
  }
}

fn disk_sectors(disk: Disk) -> List(#(Int, Option(Int))) {
  dict.to_list(disk.sectors) |> list.sort(fn(x, y) { int.compare(x.0, y.0) })
}

fn find_holes(disk: Disk) -> List(#(Int, Int)) {
  disk_sectors(disk)
  |> list.fold([], fn(holes, entry) {
    let #(sector, contents) = entry
    case contents {
      Some(_) -> holes
      None -> {
        case holes {
          [#(offset, length), ..rest] if offset + length == sector -> [
            #(offset, length + 1),
            ..rest
          ]
          _ -> [#(sector, 1), ..holes]
        }
      }
    }
  })
  |> list.reverse
}

fn find_whole_files(disk: Disk) -> List(#(Int, #(Int, Int))) {
  disk_sectors(disk)
  |> list.fold(dict.new(), fn(files, entry) {
    let #(sector, contents) = entry
    case contents {
      None -> files
      Some(id) -> {
        dict.upsert(files, id, fn(value) {
          case value {
            None -> [#(sector, 1)]
            Some([#(offset, length), ..rest]) if offset + length == sector -> [
              #(offset, length + 1),
              ..rest
            ]
            Some(rest) -> [#(sector, 1), ..rest]
          }
        })
      }
    }
  })
  |> dict.fold([], fn(files, id, chunks) {
    case chunks {
      [chunk] -> [#(id, chunk), ..files]
      _ -> files
    }
  })
  |> list.sort(fn(x, y) { int.compare(x.0, y.0) })
}

fn defrag_disk(disk: Disk) -> Disk {
  let holes = find_holes(disk)
  io.debug(holes)
  let files = find_whole_files(disk) |> list.reverse()
  io.debug(files)
  list.fold(files, #(disk, holes), fn(accum, file) {
    let #(_, holes) = accum
    let #(id, #(offset, length)) = file
    list.fold_until(holes, accum, fn(accum, hole) {
      let #(disk, holes) = accum
      let #(hole_offset, hole_length) = hole
      case hole_length >= length {
        True -> {
          let disk =
            disk
            |> fill_sectors(hole_offset, length, Some(id))
            |> fill_sectors(offset, length, None)
          let holes =
            list.map(holes, fn(h) {
              case h == hole {
                // Eh, we'll leave empty holes but whatev
                True -> #(hole_offset + length, hole_length - length)
                False -> h
              }
            })
          Stop(#(disk, holes))
        }
        False -> Continue(#(disk, holes))
      }
    })
  }).0
}

fn compute_checksum(disk: Disk) -> Int {
  let Disk(sectors) = disk
  dict.keys(sectors)
  |> list.filter(fn(sector) {
    let assert Ok(value) = dict.get(sectors, sector)
    option.is_some(value)
  })
  |> list.fold(0, fn(checksum, sector) {
    let assert Ok(Some(value)) = dict.get(sectors, sector)
    checksum + sector * value
  })
}

fn print_disk(disk: Disk) -> String {
  list.fold(disk_sectors(disk), "", fn(s, sector) {
    let #(_, contents) = sector
    case contents {
      Some(id) -> string.append(s, int.to_string(id))
      None -> string.append(s, ".")
    }
  })
}

pub fn main() {
  let path = "input0.txt"
  let assert Ok(data) = simplifile.read(path)
  let disk = parse_disk_map(data)

  let compacted = compact_disk(disk)
  io.debug(compute_checksum(compacted))

  let defragged = defrag_disk(disk)
  io.debug(compute_checksum(defragged))
  io.println("Done")
}
