import argv
import simplifile.{read}

pub fn serve(filename) {
  let assert ["--directory", file_dir] = argv.load().arguments

  read(file_dir <> filename)
}
