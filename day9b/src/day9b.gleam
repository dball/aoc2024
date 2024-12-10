import gleam/bit_array
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/yielder.{type Yielder, Done, Next}
import simplifile

type Disk {
  Disk(sectors: BitArray, next_id: Int)
}

type Block {
  Block(offset: Int, length: Int, contents: Option(Int))
}

fn sector_value(value: Option(Int)) -> Option(BitArray) {
  let v = case value {
    None -> Some(0xffff)
    Some(v) if v >= 0 && v < 0xffff -> value
    _ -> None
  }
  case v {
    None -> None
    Some(v) -> Some(<<v:size(16)>>)
  }
}

fn read_sector(disk: Disk, offset: Int) -> Option(Option(Int)) {
  // TODO bug report to gleam: docstring doesn't specify if slice is bits or bytes
  case bit_array.slice(disk.sectors, offset * 2, 2) {
    Ok(sector) -> {
      let assert <<id:unsigned-size(16)>> = sector
      case id {
        0xffff -> Some(None)
        _ -> Some(Some(id))
      }
    }
    Error(_) -> None
  }
}

fn yield_sectors(disk: Disk) -> Yielder(Option(Int)) {
  yielder.unfold(disk.sectors, fn(sectors) {
    case bit_array.slice(sectors, 0, 2) {
      Ok(sector) -> {
        let assert <<id:unsigned-size(16)>> = sector
        let contents = case id {
          0xffff -> None
          _ -> Some(id)
        }
        let assert Ok(sectors) =
          bit_array.slice(sectors, 2, bit_array.byte_size(sectors) - 2)
        Next(contents, sectors)
      }
      Error(_) -> Done
    }
  })
}

fn yield_blocks(disk: Disk) -> Yielder(Block) {
  yield_sectors(disk)
  |> yielder.index
  |> yielder.chunk(fn(entry) { entry.0 })
  |> yielder.map(fn(entry) {
    let assert Ok(first) = list.first(entry)
    #(first, list.length(entry))
  })
  |> yielder.map(fn(entry) {
    let #(#(contents, offset), length) = entry
    Block(offset, length, contents)
  })
}

fn yield_files(disk: Disk) -> Yielder(Block) {
  yield_blocks(disk)
  |> yielder.filter(fn(block) { option.is_some(block.contents) })
}

fn yield_holes(disk: Disk) -> Yielder(Block) {
  yield_blocks(disk)
  |> yielder.filter(fn(block) { option.is_none(block.contents) })
}

fn move_block(disk: Disk, block: Block, target_offset: Int) -> Disk {
  let Block(offset, length, _) = block
  let Disk(sectors, _) = disk
  let prefix_slice_offset = 0
  let prefix_slice_length = target_offset * 2
  let assert Ok(prefix_slice) =
    bit_array.slice(sectors, prefix_slice_offset, prefix_slice_length)

  let suffix_slice_offset = { offset + length } * 2
  let suffix_slice_length = bit_array.byte_size(sectors) - suffix_slice_offset
  let assert Ok(suffix_slice) =
    bit_array.slice(sectors, suffix_slice_offset, suffix_slice_length)

  let middle_slice_offset = { target_offset + length } * 2
  let middle_slice_length =
    suffix_slice_offset - { length * 2 } - middle_slice_offset
  let assert Ok(middle_slice) =
    bit_array.slice(sectors, middle_slice_offset, middle_slice_length)

  let block_slice_offset = offset * 2
  let block_slice_length = length * 2
  let assert Ok(block_slice) =
    bit_array.slice(sectors, block_slice_offset, block_slice_length)

  let target_slice_offset = target_offset * 2
  let target_slice_length = length * 2
  let assert Ok(target_slice) =
    bit_array.slice(sectors, target_slice_offset, target_slice_length)

  let sectors =
    bit_array.concat([
      prefix_slice,
      block_slice,
      middle_slice,
      target_slice,
      suffix_slice,
    ])
  Disk(..disk, sectors: sectors)
}

fn defrag_disk(disk: Disk) -> Disk {
  let files = yield_files(disk) |> yielder.to_list |> list.reverse
  list.fold(files, disk, fn(disk, file) {
    // TODO escape when first hole comes after the file
    let holes =
      yield_holes(disk)
      |> yielder.filter(fn(hole) {
        hole.length >= file.length && file.offset > hole.offset
      })
    case yielder.first(holes) {
      Error(_) -> disk
      Ok(hole) -> move_block(disk, file, hole.offset)
    }
  })
}

fn parse_disk(data: String) -> Disk {
  let #(bass, next_id) =
    data
    |> string.to_graphemes
    |> list.index_fold(#([], 0), fn(accum, char, i) {
      let #(bass, id) = accum
      let assert Ok(length) = int.parse(char)
      let #(contents, id) = case int.is_even(i) {
        True -> #(Some(id), id + 1)
        False -> #(None, id)
      }
      let assert Some(ba) = sector_value(contents)
      let bas = list.repeat(ba, length)
      #([bas, ..bass], id)
    })
  let sectors = bass |> list.reverse |> list.flatten |> bit_array.concat
  Disk(sectors: sectors, next_id: next_id)
}

fn compute_checksum(disk: Disk) -> Int {
  yield_sectors(disk)
  |> yielder.index
  |> yielder.fold(0, fn(total, entry) {
    let #(contents, offset) = entry
    case contents {
      Some(id) -> {
        total + id * offset
      }
      None -> total
    }
  })
}

pub fn main() {
  let path = "input.txt"
  let assert Ok(data) = simplifile.read(path)
  let disk = parse_disk(data)
  let defragged = defrag_disk(disk)
  io.debug(compute_checksum(defragged))
  io.println("done")
}
