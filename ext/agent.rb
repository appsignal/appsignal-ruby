# frozen_string_literal: true

# DO NOT EDIT
# This is a generated file by the `rake ship` family of tasks in the
# appsignal-agent repository.
# Modifications to this file will be overwritten with the next agent release.

APPSIGNAL_AGENT_CONFIG = {
  "version" => "bfe19b1",
  "mirrors" => [
    "https://appsignal-agent-releases.global.ssl.fastly.net",
    "https://d135dj0rjqvssy.cloudfront.net"
  ],
  "triples" => {
    "x86_64-darwin" => {
      "static" => {
        "checksum" => "0985697683dc7f2bc0a353b637e3923a79b1945f730deceba73f65807cdcbb16",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "ffa15b479a03b31a218d88fd0d381d93bd515073bf1e665a5ed6d6147e5f460f",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "universal-darwin" => {
      "static" => {
        "checksum" => "0985697683dc7f2bc0a353b637e3923a79b1945f730deceba73f65807cdcbb16",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "ffa15b479a03b31a218d88fd0d381d93bd515073bf1e665a5ed6d6147e5f460f",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-darwin" => {
      "static" => {
        "checksum" => "8fe7adac3f265d47f9bff244b357b11551065c15542e22c5e5a10afa7d3d18f9",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "336918dfa41a4252b7a2cf8250013ee210a45def3d5893eb58ca6bba71c25320",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm64-darwin" => {
      "static" => {
        "checksum" => "8fe7adac3f265d47f9bff244b357b11551065c15542e22c5e5a10afa7d3d18f9",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "336918dfa41a4252b7a2cf8250013ee210a45def3d5893eb58ca6bba71c25320",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm-darwin" => {
      "static" => {
        "checksum" => "8fe7adac3f265d47f9bff244b357b11551065c15542e22c5e5a10afa7d3d18f9",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "336918dfa41a4252b7a2cf8250013ee210a45def3d5893eb58ca6bba71c25320",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux" => {
      "static" => {
        "checksum" => "8278a46232ab0b88dfbd5276a7253f147a950ea0f55ebb104ef825a528d24b73",
        "filename" => "appsignal-aarch64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "43f737a65dae52bc2118fcb1ba0fcf35774eb5e62a1d74c0e9d3f9713c1ff1ca",
        "filename" => "appsignal-aarch64-linux-all-dynamic.tar.gz"
      }
    },
    "i686-linux" => {
      "static" => {
        "checksum" => "2b0cfc65ccd05d1258719e73fc19323729100d02a33d936ba79bb12cdede3763",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "7b163e29e6db10b21295bbdbc06c31a8158522a0a14bd4cbaf4d71a8ac432902",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86-linux" => {
      "static" => {
        "checksum" => "2b0cfc65ccd05d1258719e73fc19323729100d02a33d936ba79bb12cdede3763",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "7b163e29e6db10b21295bbdbc06c31a8158522a0a14bd4cbaf4d71a8ac432902",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux" => {
      "static" => {
        "checksum" => "10bafbef6445ea1a37529b34fb103dd48e185f61f19f58f573377127d03f6a60",
        "filename" => "appsignal-x86_64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "bc6a5ffea46fc3e440a580344340e5dd0274372aae34132957707be0c0dc0bd2",
        "filename" => "appsignal-x86_64-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux-musl" => {
      "static" => {
        "checksum" => "fba0b10a3dcac0854cd9d19773ab48649fc79a35261eacdfe28d6e70c267b98a",
        "filename" => "appsignal-x86_64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "50f1c3f9102adb666ec27ac4aaab27193bf8896d64e3b4a2ba94c042f04f1cb7",
        "filename" => "appsignal-x86_64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux-musl" => {
      "static" => {
        "checksum" => "98e8aafa0f688b1f1a9c37daf9e9cc1e36edc7e0ad65f86d8402469d15b6a1d6",
        "filename" => "appsignal-aarch64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "55dfab323718bc731678ff1268c9fa2e78de37ab39fb8b46aa806bfd41df4212",
        "filename" => "appsignal-aarch64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "x86_64-freebsd" => {
      "static" => {
        "checksum" => "09ebc6406d81fdf81b2e76bef6c1344f34292e1b3727f7fc984c8df5c7698db5",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "cdab19e2e6d5f6ad15f3d87f735cd867e7c54db0412c893c39de3521afd9b6d3",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    },
    "amd64-freebsd" => {
      "static" => {
        "checksum" => "09ebc6406d81fdf81b2e76bef6c1344f34292e1b3727f7fc984c8df5c7698db5",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "cdab19e2e6d5f6ad15f3d87f735cd867e7c54db0412c893c39de3521afd9b6d3",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    }
  }
}.freeze
