///|
fn main {
  let argv = @sys.get_cli_args()
  try! @lib.run_emulator(argv.get(1))
}
