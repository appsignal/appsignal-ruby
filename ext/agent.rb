# frozen_string_literal: true

# DO NOT EDIT
# This is a generated file by the `rake publish` family of tasks in the
# appsignal-agent repository.
# Modifications to this file will be overwritten with the next agent release.

APPSIGNAL_AGENT_CONFIG = {
  "version" => "0.35.26",
  "mirrors" => [
    "https://d135dj0rjqvssy.cloudfront.net",
    "https://appsignal-agent-releases.global.ssl.fastly.net"
  ],
  "triples" => {
    "x86_64-darwin" => {
      "static" => {
        "checksum" => "e0b0674dad04528f14048a0941fdacf9cbdb317627116c9b4dd7b786e572caa3",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "a30a6502787df7354da94e0c86eff92745b712d916cb2740a7fdb412add15ffc",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "universal-darwin" => {
      "static" => {
        "checksum" => "e0b0674dad04528f14048a0941fdacf9cbdb317627116c9b4dd7b786e572caa3",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "a30a6502787df7354da94e0c86eff92745b712d916cb2740a7fdb412add15ffc",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-darwin" => {
      "static" => {
        "checksum" => "377d6eac5dc10de28275ec88a368f1c5da61438afa41f0767803d6c3a9399717",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "45dfb897e2aaacbe7e638f88781d50059c6cb1fcce624e33bef409c75e70ac7f",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm64-darwin" => {
      "static" => {
        "checksum" => "377d6eac5dc10de28275ec88a368f1c5da61438afa41f0767803d6c3a9399717",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "45dfb897e2aaacbe7e638f88781d50059c6cb1fcce624e33bef409c75e70ac7f",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm-darwin" => {
      "static" => {
        "checksum" => "377d6eac5dc10de28275ec88a368f1c5da61438afa41f0767803d6c3a9399717",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "45dfb897e2aaacbe7e638f88781d50059c6cb1fcce624e33bef409c75e70ac7f",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux" => {
      "static" => {
        "checksum" => "67f927b89d9ef65f063c487bcd5bef832051a547d0b0f911589b4f90554c3185",
        "filename" => "appsignal-aarch64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "291fbaddd0fb48d300268fe80c41b069d2669da2e592a27831b13e850983c247",
        "filename" => "appsignal-aarch64-linux-all-dynamic.tar.gz"
      }
    },
    "i686-linux" => {
      "static" => {
        "checksum" => "aee4d5a74c0d5a39bf7047b2fb0c1ab0af4151bdf20b23c7095b024d8f34d6eb",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "2bb793d036e7f605c0bb56b7c70a5107c4dd29a37966cdc33358287403b52c0a",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86-linux" => {
      "static" => {
        "checksum" => "aee4d5a74c0d5a39bf7047b2fb0c1ab0af4151bdf20b23c7095b024d8f34d6eb",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "2bb793d036e7f605c0bb56b7c70a5107c4dd29a37966cdc33358287403b52c0a",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux" => {
      "static" => {
        "checksum" => "595eef52453a179a6c5fde2a5d7206a85e07970a2dbceb631a19af20e05b46db",
        "filename" => "appsignal-x86_64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "018754bf36f98246d961caf2d115ce345bf6f74fa160c2cbfa733820cd787396",
        "filename" => "appsignal-x86_64-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux-musl" => {
      "static" => {
        "checksum" => "5992db83dc784e4aaec4cc4d4ebbd62a9d68ae7197697c34f3d4d820233c3238",
        "filename" => "appsignal-x86_64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "4b93de4ba07614c313822ee5cbc1d2f3dea2c864fe91e3b0ec6c79927a9e58e5",
        "filename" => "appsignal-x86_64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux-musl" => {
      "static" => {
        "checksum" => "f5d35cea12db1d473757d5fbed9c66e2018b6eaf35e0c96b2787f67e08ceae13",
        "filename" => "appsignal-aarch64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "70309cff2e3f5330156c8ea530ccc537d4113eabe1d21590f8363c22803719fe",
        "filename" => "appsignal-aarch64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "x86_64-freebsd" => {
      "static" => {
        "checksum" => "6a696cde1d84fbc56e152d560100bd941276e7b1ddda38de81bc3e985780366a",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "184e8fdb8bd69f0d0bd5fec1da66ae6ea87d2f447aac56e91d7a89e31c2c0cd0",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    },
    "amd64-freebsd" => {
      "static" => {
        "checksum" => "6a696cde1d84fbc56e152d560100bd941276e7b1ddda38de81bc3e985780366a",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "184e8fdb8bd69f0d0bd5fec1da66ae6ea87d2f447aac56e91d7a89e31c2c0cd0",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    }
  }
}.freeze
