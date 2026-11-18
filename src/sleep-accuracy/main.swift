import Foundation

// The sleep accuracy harness's command line (spec 019). A stub until the commands are wired up.

let usage = """
    usage: sleep-accuracy walch --data <dir> --out <dir> (--threshold <deg> | --sweep <deg,…>)
           sleep-accuracy strap --data <dir> --out <dir> --threshold <deg>
    """
FileHandle.standardError.write(Data((usage + "\n").utf8))
exit(1)
