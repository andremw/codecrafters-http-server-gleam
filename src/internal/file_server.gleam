import argv
import simplifile.{read, write}

pub fn serve(filename) {
  let file_dir = get_file_dir()

  read(file_dir <> filename)
}

pub fn create(filename, content) {
  let file_dir = get_file_dir()

  write(file_dir <> "/" <> filename, content)
}

fn get_file_dir() {
  let assert ["--directory", file_dir] = argv.load().arguments
  file_dir
}
