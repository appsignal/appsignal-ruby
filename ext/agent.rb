# frozen_string_literal: true

# DO NOT EDIT
# This is a generated file by the `rake publish` family of tasks in the
# appsignal-agent repository.
# Modifications to this file will be overwritten with the next agent release.

APPSIGNAL_AGENT_CONFIG = {
  "version" => "0.36.5",
  "mirrors" => [
    "https://d135dj0rjqvssy.cloudfront.net",
    "https://appsignal-agent-releases.global.ssl.fastly.net"
  ],
  "triples" => {
    "x86_64-darwin" => {
      "static" => {
        "checksum" => "174222cc211a50eefa35f1b2391f94ea1a0fede07ab4210f90764ea4353e24f7",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "5057e7e99d033765bc49e949f2c313299430cdcdce257d2ee2e7f0565be38776",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "universal-darwin" => {
      "static" => {
        "checksum" => "174222cc211a50eefa35f1b2391f94ea1a0fede07ab4210f90764ea4353e24f7",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "5057e7e99d033765bc49e949f2c313299430cdcdce257d2ee2e7f0565be38776",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-darwin" => {
      "static" => {
        "checksum" => "54d9687a716c5e607f92aa93782b1c64fe064d4a42c58473e0b07eb313378103",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "3b6e420e306856c3d35fefb3a1e0b57cbc4623732a661517ccb75ab0657b5aa5",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm64-darwin" => {
      "static" => {
        "checksum" => "54d9687a716c5e607f92aa93782b1c64fe064d4a42c58473e0b07eb313378103",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "3b6e420e306856c3d35fefb3a1e0b57cbc4623732a661517ccb75ab0657b5aa5",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm-darwin" => {
      "static" => {
        "checksum" => "54d9687a716c5e607f92aa93782b1c64fe064d4a42c58473e0b07eb313378103",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "3b6e420e306856c3d35fefb3a1e0b57cbc4623732a661517ccb75ab0657b5aa5",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux" => {
      "static" => {
        "checksum" => "59746a7fe722eb9c985e155aeaefdab37d96a96f650eff81b8610955b09edebb",
        "filename" => "appsignal-aarch64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "6a8c597ed646790c6a70913a8be70e2cc7cc022a3ffedf7b1df6e003b1781aea",
        "filename" => "appsignal-aarch64-linux-all-dynamic.tar.gz"
      }
    },
    "i686-linux" => {
      "static" => {
        "checksum" => "4202807069dcd2b9df2c478273f7ce23f88e47224e75a5062592ed6af8a675ec",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "34a6b6502eb924c60fe98a4c0d62fc83b8ca210beb334c559f909cad24276312",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86-linux" => {
      "static" => {
        "checksum" => "4202807069dcd2b9df2c478273f7ce23f88e47224e75a5062592ed6af8a675ec",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "34a6b6502eb924c60fe98a4c0d62fc83b8ca210beb334c559f909cad24276312",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux" => {
      "static" => {
        "checksum" => "948ae7a80b5c33807ddfd7f7e575515db76868dc4750993e658a19920db43d99",
        "filename" => "appsignal-x86_64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "bdc95b8c5da28802c4023eb48d30aa7f8c4ec85484436d083f43fea0087c946e",
        "filename" => "appsignal-x86_64-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux-musl" => {
      "static" => {
        "checksum" => "e9d717aecfe1a7bcc139289b8aa10d3e4e52f487776cd1a26025ac13b55b7754",
        "filename" => "appsignal-x86_64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "bef8053e0bf3cc35f21e448360ae3f0e63a3be82e44473fcdf15022f0d7536c4",
        "filename" => "appsignal-x86_64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux-musl" => {
      "static" => {
        "checksum" => "313affebfe45a3d31a368e39cb3f1ea3860de21282c52ad97c0d194a9dbd52e8",
        "filename" => "appsignal-aarch64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "8f36aea4e175b60627172521ef40eda5f52bc995b52ac2a23b30cf93d59052c4",
        "filename" => "appsignal-aarch64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "x86_64-freebsd" => {
      "static" => {
        "checksum" => "b35d43501b22bf9a98fc37545932fe79c4adee3cea7c4b5a677266a858ceab88",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "ce0d483848b5d44a5a1dfa5f9bc7d9299d9c7c9c5e5a9e1f0b7b5793a01aa349",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    },
    "amd64-freebsd" => {
      "static" => {
        "checksum" => "b35d43501b22bf9a98fc37545932fe79c4adee3cea7c4b5a677266a858ceab88",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "ce0d483848b5d44a5a1dfa5f9bc7d9299d9c7c9c5e5a9e1f0b7b5793a01aa349",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    }
  }
}.freeze
