# frozen_string_literal: true

# DO NOT EDIT
# This is a generated file by the `rake ship` family of tasks in the
# appsignal-agent repository.
# Modifications to this file will be overwritten with the next agent release.

APPSIGNAL_AGENT_CONFIG = {
  "version" => "0.35.19",
  "mirrors" => [
    "https://appsignal-agent-releases.global.ssl.fastly.net",
    "https://d135dj0rjqvssy.cloudfront.net"
  ],
  "triples" => {
    "x86_64-darwin" => {
      "static" => {
        "checksum" => "0d465ca77500f7e9675d262a5ccd277fc3428821ac96f973b9941ad49a300ea9",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "ff1b90c3c52e5b765dc8c43b2c0fe376a06101134ec5879d581642ed6837603e",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "universal-darwin" => {
      "static" => {
        "checksum" => "0d465ca77500f7e9675d262a5ccd277fc3428821ac96f973b9941ad49a300ea9",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "ff1b90c3c52e5b765dc8c43b2c0fe376a06101134ec5879d581642ed6837603e",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-darwin" => {
      "static" => {
        "checksum" => "7c735e7490d9d5313e76a0e0508f85983c98caceb0507afa3d8d34bb3b740627",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "c29689978f56904771c6caa151a35d8bea3ba4002b6e767ddc102f82d9909fa2",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm64-darwin" => {
      "static" => {
        "checksum" => "7c735e7490d9d5313e76a0e0508f85983c98caceb0507afa3d8d34bb3b740627",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "c29689978f56904771c6caa151a35d8bea3ba4002b6e767ddc102f82d9909fa2",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm-darwin" => {
      "static" => {
        "checksum" => "7c735e7490d9d5313e76a0e0508f85983c98caceb0507afa3d8d34bb3b740627",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "c29689978f56904771c6caa151a35d8bea3ba4002b6e767ddc102f82d9909fa2",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux" => {
      "static" => {
        "checksum" => "6ed44186487547614b1a2d4f1c2fea4676f2b5829c8949ad86ca61a66db716e7",
        "filename" => "appsignal-aarch64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "775399b3b559f1c8bd931fb835a88dee012fb62d580584b8e6f4d40ea24f6a0a",
        "filename" => "appsignal-aarch64-linux-all-dynamic.tar.gz"
      }
    },
    "i686-linux" => {
      "static" => {
        "checksum" => "608b8de770ddc9cbc9cae16f793c630079d640b3b77f3af2f854de474e8ef5de",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "87e893f27ec2128d953c65c46dd0136a0dfab50eab18ec2a3a47cfff8068ca89",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86-linux" => {
      "static" => {
        "checksum" => "608b8de770ddc9cbc9cae16f793c630079d640b3b77f3af2f854de474e8ef5de",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "87e893f27ec2128d953c65c46dd0136a0dfab50eab18ec2a3a47cfff8068ca89",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux" => {
      "static" => {
        "checksum" => "4499818ce89075c7754e26c8915b452352a155619f2ce648232fad6480638f34",
        "filename" => "appsignal-x86_64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "70b60e4af4c17c569869293680f5d71ea3c3ab2be8a64dfa02421b431f6a5b7b",
        "filename" => "appsignal-x86_64-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux-musl" => {
      "static" => {
        "checksum" => "ed3a557d8ae6aeb15597ff40dce3739c350053a24d163ddc362af20e7e9d4e1c",
        "filename" => "appsignal-x86_64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "594cb5216a260f315481e1c6d56af978716f2736653374c3ea52270a355e673d",
        "filename" => "appsignal-x86_64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux-musl" => {
      "static" => {
        "checksum" => "f18731c7c549cf635ec8b040c3dbd3cdc3285f0e240c2790a8c8003e0ff7cbee",
        "filename" => "appsignal-aarch64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "e7bb93dba7975920539e7d270752c690de9e1e292da5f9b2c0e66863b0c8caf7",
        "filename" => "appsignal-aarch64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "x86_64-freebsd" => {
      "static" => {
        "checksum" => "fa2c007ca5cb40ac75b7c147d18460edcb0d948648286debc03d4f5afda469f1",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "e0e3b59374e7b32eefcc7877a81d0d4d3bcf0d756d7e8cbff3a44444506fa00c",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    },
    "amd64-freebsd" => {
      "static" => {
        "checksum" => "fa2c007ca5cb40ac75b7c147d18460edcb0d948648286debc03d4f5afda469f1",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "e0e3b59374e7b32eefcc7877a81d0d4d3bcf0d756d7e8cbff3a44444506fa00c",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    }
  }
}.freeze
