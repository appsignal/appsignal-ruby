# frozen_string_literal: true

# DO NOT EDIT
# This is a generated file by the `rake ship` family of tasks in the
# appsignal-agent repository.
# Modifications to this file will be overwritten with the next agent release.

APPSIGNAL_AGENT_CONFIG = {
  "version" => "32590eb",
  "mirrors" => [
    "https://appsignal-agent-releases.global.ssl.fastly.net",
    "https://d135dj0rjqvssy.cloudfront.net"
  ],
  "triples" => {
    "x86_64-darwin" => {
      "static" => {
        "checksum" => "d19ddec878fd1c608bfc44219eee3059676e329575af0a0f9077a6ebd13ab759",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "068b99cc5b758e5657cdfe152e2c2ff6a7b53b5d1d14fb7b7f4aa2cb7eab37f3",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "universal-darwin" => {
      "static" => {
        "checksum" => "d19ddec878fd1c608bfc44219eee3059676e329575af0a0f9077a6ebd13ab759",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "068b99cc5b758e5657cdfe152e2c2ff6a7b53b5d1d14fb7b7f4aa2cb7eab37f3",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-darwin" => {
      "static" => {
        "checksum" => "ee637a448d7f063a603b34bff2a0387842fd9b7efe477f43c69850d1bde649d8",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "3c8f7f9c3ca53ca9c600290af1f033a96bff477ac8de236da23f5e3fd17643b2",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm64-darwin" => {
      "static" => {
        "checksum" => "ee637a448d7f063a603b34bff2a0387842fd9b7efe477f43c69850d1bde649d8",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "3c8f7f9c3ca53ca9c600290af1f033a96bff477ac8de236da23f5e3fd17643b2",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm-darwin" => {
      "static" => {
        "checksum" => "ee637a448d7f063a603b34bff2a0387842fd9b7efe477f43c69850d1bde649d8",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "3c8f7f9c3ca53ca9c600290af1f033a96bff477ac8de236da23f5e3fd17643b2",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux" => {
      "static" => {
        "checksum" => "c723895a2b627dc9bd6f756468206bb8b946e1ddaeab13f2562d47765bcbdc92",
        "filename" => "appsignal-aarch64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "a6d2bbd5659eb933274e47ebd1bddf5e124e641ddbf565aee2f46502bd77fdc9",
        "filename" => "appsignal-aarch64-linux-all-dynamic.tar.gz"
      }
    },
    "i686-linux" => {
      "static" => {
        "checksum" => "7e8e9b0ba5bde6ed3b3c697eb5c92c1840e0ab1a0ecad1e588d684c04f5aad2b",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "65a47275eee9e75102398df2f8e6ba89ec1f47a3b017a9b97dffa314b76c4cd1",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86-linux" => {
      "static" => {
        "checksum" => "7e8e9b0ba5bde6ed3b3c697eb5c92c1840e0ab1a0ecad1e588d684c04f5aad2b",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "65a47275eee9e75102398df2f8e6ba89ec1f47a3b017a9b97dffa314b76c4cd1",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux" => {
      "static" => {
        "checksum" => "b34f064d17a7ab047ebb0eac512452ed4ea91eb7035cd3caa5c06ec8c425ef8e",
        "filename" => "appsignal-x86_64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "7ae57a256a6a2115e5c36cab6d93d8c9ab63ffc9ff21f067b3e3769b4d847245",
        "filename" => "appsignal-x86_64-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux-musl" => {
      "static" => {
        "checksum" => "543e47617392cfc243aa053280cd98804ce71728ddd3e38c9b5c6f62a6006b97",
        "filename" => "appsignal-x86_64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "33ecdddcfb6eb9b895346355ab79d97b0c7258d19d9cdfe8d3ec0f384657bce5",
        "filename" => "appsignal-x86_64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux-musl" => {
      "static" => {
        "checksum" => "7e44a1e739f1d4e01fec73cdb4878c0b0b6af5b0f5b433f30807d768fd0cf2f0",
        "filename" => "appsignal-aarch64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "5319e91e5341e19b9ce58b93d439822c35511469a4a08e8e3b6afc75e95dd119",
        "filename" => "appsignal-aarch64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "x86_64-freebsd" => {
      "static" => {
        "checksum" => "5ddb4d0d357fbb4677156f538f325924fa53f7fbba5885761b58596fc2ded8ad",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "5a556a299d69b87c914dca1e0b19cfe1beb4b07ef003e88809600f309117c746",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    },
    "amd64-freebsd" => {
      "static" => {
        "checksum" => "5ddb4d0d357fbb4677156f538f325924fa53f7fbba5885761b58596fc2ded8ad",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "5a556a299d69b87c914dca1e0b19cfe1beb4b07ef003e88809600f309117c746",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    }
  }
}.freeze
