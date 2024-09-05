# frozen_string_literal: true

# DO NOT EDIT
# This is a generated file by the `rake ship` family of tasks in the
# appsignal-agent repository.
# Modifications to this file will be overwritten with the next agent release.

APPSIGNAL_AGENT_CONFIG = {
  "version" => "0.35.24",
  "mirrors" => [
    "https://appsignal-agent-releases.global.ssl.fastly.net",
    "https://d135dj0rjqvssy.cloudfront.net"
  ],
  "triples" => {
    "x86_64-darwin" => {
      "static" => {
        "checksum" => "5e84f2239cc9d7019a08d9076e1f021e282698c4e9dbd4cc748c1fb63a1bdabe",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "b1f5861c46ca61681039b12d5fbd454ca0d953862fccc6e94890a0283c89eafd",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "universal-darwin" => {
      "static" => {
        "checksum" => "5e84f2239cc9d7019a08d9076e1f021e282698c4e9dbd4cc748c1fb63a1bdabe",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "b1f5861c46ca61681039b12d5fbd454ca0d953862fccc6e94890a0283c89eafd",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-darwin" => {
      "static" => {
        "checksum" => "b3d64e6f73c81a66e9a19647d02792140f129209563dc4e95baf9148bb7ea159",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "67b996373e29e848762930940b1c9c790378125002d01fe0ece599100e5fccda",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm64-darwin" => {
      "static" => {
        "checksum" => "b3d64e6f73c81a66e9a19647d02792140f129209563dc4e95baf9148bb7ea159",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "67b996373e29e848762930940b1c9c790378125002d01fe0ece599100e5fccda",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm-darwin" => {
      "static" => {
        "checksum" => "b3d64e6f73c81a66e9a19647d02792140f129209563dc4e95baf9148bb7ea159",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "67b996373e29e848762930940b1c9c790378125002d01fe0ece599100e5fccda",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux" => {
      "static" => {
        "checksum" => "df88da006c7de613f9461be51a232bcfebbe58a6a8a4a406ef52c436526be10d",
        "filename" => "appsignal-aarch64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "3001d13ea6f03472323345be21e9cb9c6db895405de47273968946746bbce593",
        "filename" => "appsignal-aarch64-linux-all-dynamic.tar.gz"
      }
    },
    "i686-linux" => {
      "static" => {
        "checksum" => "2a2c005e26196e3008f52e909b192e61ccc39c2a942980bb6177222cdfcb801b",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "18e74b0ae51208d439b252b55f340df563bbf1f945f31a70139f2a973530962f",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86-linux" => {
      "static" => {
        "checksum" => "2a2c005e26196e3008f52e909b192e61ccc39c2a942980bb6177222cdfcb801b",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "18e74b0ae51208d439b252b55f340df563bbf1f945f31a70139f2a973530962f",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux" => {
      "static" => {
        "checksum" => "2e2545f7ef725c644fa597c7e9b46d9725f3584e2e57a84fd4c00c3eabdf61ae",
        "filename" => "appsignal-x86_64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "29ee43e441c3d43615e6bd10f234939f289ebad5d88b91ab78ee881ac954261c",
        "filename" => "appsignal-x86_64-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux-musl" => {
      "static" => {
        "checksum" => "eb60a12950fe1eaa13225aefa6da2295384380f3a31e3377f4a107edd2b360ae",
        "filename" => "appsignal-x86_64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "66f332e66c17d0e4234c923e266b8191596e2288afdeb9330b967bd75b1925e4",
        "filename" => "appsignal-x86_64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux-musl" => {
      "static" => {
        "checksum" => "3f4e0be8e197dae26a6e75f41ac8def681b6611fe0089b9236aa2837fb36d0de",
        "filename" => "appsignal-aarch64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "fcde2bbb659c8797c493adbb09b8558e528b5cac5e5dca6ad594d16ec464d798",
        "filename" => "appsignal-aarch64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "x86_64-freebsd" => {
      "static" => {
        "checksum" => "e45ab5335f68658c13cd79dc751400544a2e17c7ad4fe025dd0c53c3d19138ec",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "107a24d1f1023b72ff483b21f773a70788b3bfa9decbcb045861211d0a3f6e7b",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    },
    "amd64-freebsd" => {
      "static" => {
        "checksum" => "e45ab5335f68658c13cd79dc751400544a2e17c7ad4fe025dd0c53c3d19138ec",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "107a24d1f1023b72ff483b21f773a70788b3bfa9decbcb045861211d0a3f6e7b",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    }
  }
}.freeze
