# frozen_string_literal: true

# DO NOT EDIT
# This is a generated file by the `rake publish` family of tasks in the
# appsignal-agent repository.
# Modifications to this file will be overwritten with the next agent release.

APPSIGNAL_AGENT_CONFIG = {
  "version" => "0.36.12",
  "mirrors" => [
    "https://d135dj0rjqvssy.cloudfront.net",
    "https://appsignal-agent-releases.global.ssl.fastly.net"
  ],
  "triples" => {
    "x86_64-darwin" => {
      "static" => {
        "checksum" => "a63189a2ba6b500e038e5658f97478ceae27a956baa2f89a4e79ee5a1dadace6",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "ecfb108dcc4d10f442415debaceed6d2e568b44ab938cf0ed6fee3ccfbdc5379",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "universal-darwin" => {
      "static" => {
        "checksum" => "a63189a2ba6b500e038e5658f97478ceae27a956baa2f89a4e79ee5a1dadace6",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "ecfb108dcc4d10f442415debaceed6d2e568b44ab938cf0ed6fee3ccfbdc5379",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-darwin" => {
      "static" => {
        "checksum" => "d23d6cc15e7df1c810b55dc33905002c5a1d6bc3f7cb10690d7e21398aabdac0",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "b4f9bf20f87fc7ddd8cc307646a956f734a2153323cc01487ced322263f32c2b",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm64-darwin" => {
      "static" => {
        "checksum" => "d23d6cc15e7df1c810b55dc33905002c5a1d6bc3f7cb10690d7e21398aabdac0",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "b4f9bf20f87fc7ddd8cc307646a956f734a2153323cc01487ced322263f32c2b",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm-darwin" => {
      "static" => {
        "checksum" => "d23d6cc15e7df1c810b55dc33905002c5a1d6bc3f7cb10690d7e21398aabdac0",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "b4f9bf20f87fc7ddd8cc307646a956f734a2153323cc01487ced322263f32c2b",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux" => {
      "static" => {
        "checksum" => "0a277e682f1568fbc54df849a46f21f155643b40c285a5bd30294c9d046e49c2",
        "filename" => "appsignal-aarch64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "94e0193908955e7a3a274a37947e234c5b038aa26c0ea9b371a08fd63441a940",
        "filename" => "appsignal-aarch64-linux-all-dynamic.tar.gz"
      }
    },
    "i686-linux" => {
      "static" => {
        "checksum" => "0d4536a2b1c9b6915f0f8597bd858988e284e7dbc4a14488332ffa7e401a1134",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "c5df66876e4611d5ef8798013f0188469cbdea6753a9b9d6cf54bd858e6331e9",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86-linux" => {
      "static" => {
        "checksum" => "0d4536a2b1c9b6915f0f8597bd858988e284e7dbc4a14488332ffa7e401a1134",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "c5df66876e4611d5ef8798013f0188469cbdea6753a9b9d6cf54bd858e6331e9",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux" => {
      "static" => {
        "checksum" => "eec59a3e46dd5d5baff044465b4e314f21edf6270500bf24e3bc50afcee5f2e2",
        "filename" => "appsignal-x86_64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "37471e17c5cb9f252d039cfbc0c01d570698c2245f6c8783fd2778e640b59a54",
        "filename" => "appsignal-x86_64-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux-musl" => {
      "static" => {
        "checksum" => "4454ec095ad14813bedea20a110a26235dbc6e8e33538219fad325792c0d888e",
        "filename" => "appsignal-x86_64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "4c21039b077b0c292d530210e077d942694f4c533d3761ed11e27ca932215131",
        "filename" => "appsignal-x86_64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux-musl" => {
      "static" => {
        "checksum" => "048a55f0f10087e7954559d6cd09b371a0b532673f7ca769bcfde5729e297a72",
        "filename" => "appsignal-aarch64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "8dc336cffcb2cffe85daa8c70b02b0af7e626ed81c8873cdbb627216a411d59a",
        "filename" => "appsignal-aarch64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "x86_64-freebsd" => {
      "static" => {
        "checksum" => "d81d039a3c1936bd393a6140b46f48092da31600b0311eab819acd777521a588",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "cc345d4a791200e5af53c533e7ad83d278e98ee0becb5b54e502ba8934094372",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    },
    "amd64-freebsd" => {
      "static" => {
        "checksum" => "d81d039a3c1936bd393a6140b46f48092da31600b0311eab819acd777521a588",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "cc345d4a791200e5af53c533e7ad83d278e98ee0becb5b54e502ba8934094372",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    }
  }
}.freeze
