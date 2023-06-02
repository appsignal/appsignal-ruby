# frozen_string_literal: true

# DO NOT EDIT
# This is a generated file by the `rake ship` family of tasks in the
# appsignal-agent repository.
# Modifications to this file will be overwritten with the next agent release.

APPSIGNAL_AGENT_CONFIG = {
  "version" => "fd8ee9e",
  "mirrors" => [
    "https://appsignal-agent-releases.global.ssl.fastly.net",
    "https://d135dj0rjqvssy.cloudfront.net"
  ],
  "triples" => {
    "x86_64-darwin" => {
      "static" => {
        "checksum" => "38731cb50e31377053618cd3687ab99d10cc991171b73ea81a40aab49d415fe1",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "d86f34a30a2cfc613f3af9bd84ddec0955af0644204cc394e0141860b201506a",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "universal-darwin" => {
      "static" => {
        "checksum" => "38731cb50e31377053618cd3687ab99d10cc991171b73ea81a40aab49d415fe1",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "d86f34a30a2cfc613f3af9bd84ddec0955af0644204cc394e0141860b201506a",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-darwin" => {
      "static" => {
        "checksum" => "ee791758b84b56ce01482c1c3f65db926457558275f22673442e19a4e9b9c43e",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "99bbb1d7072849196b7581abf3fbe8e060b6a794a868302988d38eb049b42352",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm64-darwin" => {
      "static" => {
        "checksum" => "ee791758b84b56ce01482c1c3f65db926457558275f22673442e19a4e9b9c43e",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "99bbb1d7072849196b7581abf3fbe8e060b6a794a868302988d38eb049b42352",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm-darwin" => {
      "static" => {
        "checksum" => "ee791758b84b56ce01482c1c3f65db926457558275f22673442e19a4e9b9c43e",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "99bbb1d7072849196b7581abf3fbe8e060b6a794a868302988d38eb049b42352",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux" => {
      "static" => {
        "checksum" => "65ccb3ed4fdc7f55671ca4ff04beaa97bb01835e0f30b6a5f2e02dbe8b5c31f4",
        "filename" => "appsignal-aarch64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "2dfd4991a4607d5a240d8c46e8449e7dc979ed07155519cb60b840ac264e1daa",
        "filename" => "appsignal-aarch64-linux-all-dynamic.tar.gz"
      }
    },
    "i686-linux" => {
      "static" => {
        "checksum" => "849d2a2ff27814961e1ce9183877a0aedda263f538b0dbfa5e17357e2af00ba4",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "3d5f513d9e6a98a2619b798ead5edeef232654eefa1dabe55930acc662bc69b1",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86-linux" => {
      "static" => {
        "checksum" => "849d2a2ff27814961e1ce9183877a0aedda263f538b0dbfa5e17357e2af00ba4",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "3d5f513d9e6a98a2619b798ead5edeef232654eefa1dabe55930acc662bc69b1",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux" => {
      "static" => {
        "checksum" => "907889dbc50c5f670c1edce503b6f1cdacc52127217611df56b4913137e814f1",
        "filename" => "appsignal-x86_64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "7b4ef01a26aec35d892f4c89ac246b0e44d22f8e75b4fb60ed82d458f00e0a71",
        "filename" => "appsignal-x86_64-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux-musl" => {
      "static" => {
        "checksum" => "f4b26fbee43be4bf15033cd3594d8a79d5cd73a95aa62e1949e3a0836345af03",
        "filename" => "appsignal-x86_64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "b7e0885ce6a19c42781b36c7876e729320df16492630972b47a12096333d9e46",
        "filename" => "appsignal-x86_64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux-musl" => {
      "static" => {
        "checksum" => "d316c1a6a92963ba88c1c578a070eba505e1a466e3af768362122d935af31ccd",
        "filename" => "appsignal-aarch64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "fcfcfc277e44b87057221e34813146f614a3509128fcd3fe7bc9d8eaf7959a2c",
        "filename" => "appsignal-aarch64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "x86_64-freebsd" => {
      "static" => {
        "checksum" => "c2d8f903e683ce77f608d7e8d1eadc98a0fd29d19f07110e04cc73c5d2cb887c",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "7d07f06c7a1d86b78cc134213f1c797f1fab4454c274e1e148764f145e1ec30a",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    },
    "amd64-freebsd" => {
      "static" => {
        "checksum" => "c2d8f903e683ce77f608d7e8d1eadc98a0fd29d19f07110e04cc73c5d2cb887c",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "7d07f06c7a1d86b78cc134213f1c797f1fab4454c274e1e148764f145e1ec30a",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    }
  }
}.freeze
