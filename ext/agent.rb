# frozen_string_literal: true

# DO NOT EDIT
# This is a generated file by the `rake publish` family of tasks in the
# appsignal-agent repository.
# Modifications to this file will be overwritten with the next agent release.

APPSIGNAL_AGENT_CONFIG = {
  "version" => "0.36.1",
  "mirrors" => [
    "https://d135dj0rjqvssy.cloudfront.net",
    "https://appsignal-agent-releases.global.ssl.fastly.net"
  ],
  "triples" => {
    "x86_64-darwin" => {
      "static" => {
        "checksum" => "b04866a9f8d5002d37e4142c0d95281a18b14afdb7f43d9cd27ed457c18ba605",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "4cab2c7e5d0638080af69796d5f59b9be2b80b3c8b8080fdb17963428a765b74",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "universal-darwin" => {
      "static" => {
        "checksum" => "b04866a9f8d5002d37e4142c0d95281a18b14afdb7f43d9cd27ed457c18ba605",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "4cab2c7e5d0638080af69796d5f59b9be2b80b3c8b8080fdb17963428a765b74",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-darwin" => {
      "static" => {
        "checksum" => "2449f66f00a2c4999f7e46527377127df70b8d1dbc15460987d3cc7878189e02",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "2dc49c41d82444d81f2652facc580e331025e3cfcf6be4094e997ee59549f27c",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm64-darwin" => {
      "static" => {
        "checksum" => "2449f66f00a2c4999f7e46527377127df70b8d1dbc15460987d3cc7878189e02",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "2dc49c41d82444d81f2652facc580e331025e3cfcf6be4094e997ee59549f27c",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm-darwin" => {
      "static" => {
        "checksum" => "2449f66f00a2c4999f7e46527377127df70b8d1dbc15460987d3cc7878189e02",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "2dc49c41d82444d81f2652facc580e331025e3cfcf6be4094e997ee59549f27c",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux" => {
      "static" => {
        "checksum" => "8177ee4235fe031371e9bd7f8b0cb782c4825ed5fafbee7f7984564d813ce712",
        "filename" => "appsignal-aarch64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "fd935e29f0c4c309c948f00156c6d6b70bb4c744898e0da97497ef2b39f131bc",
        "filename" => "appsignal-aarch64-linux-all-dynamic.tar.gz"
      }
    },
    "i686-linux" => {
      "static" => {
        "checksum" => "ef073d456d4f676836a238e83f177851b2568993adb9c2a952e9bf2b700069a9",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "b15677cdee4b6efa744730a86e32939fbe21f0fef2870651ca7d901159b6dbf1",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86-linux" => {
      "static" => {
        "checksum" => "ef073d456d4f676836a238e83f177851b2568993adb9c2a952e9bf2b700069a9",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "b15677cdee4b6efa744730a86e32939fbe21f0fef2870651ca7d901159b6dbf1",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux" => {
      "static" => {
        "checksum" => "9701b9cb4b904dc51c08a7cd044f03194ca1f2029ee6bf7fa74514e62bf5b6bd",
        "filename" => "appsignal-x86_64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "d9d8bf9a81597e4838dcc476bed4176e693e710d7655777371a2304b61f489fc",
        "filename" => "appsignal-x86_64-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux-musl" => {
      "static" => {
        "checksum" => "fde82104787e0531ea816019b0c7a9e16afb29fb015c1776faaa7ccd5cb4f60c",
        "filename" => "appsignal-x86_64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "e629bfd8e5e3d57a2a5b67ca4fa58371580837a1691b665197801b614823466f",
        "filename" => "appsignal-x86_64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux-musl" => {
      "static" => {
        "checksum" => "95876c74ea67fa9b5e14d4a84df2d91c78b23f471339addc6b7b624e3ea3fbe7",
        "filename" => "appsignal-aarch64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "1067914ece274c34c692ef1c28877163a8faa985518a4d931ead51816b03f8a7",
        "filename" => "appsignal-aarch64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "x86_64-freebsd" => {
      "static" => {
        "checksum" => "478de9db74f9fc9c32fd34c7c7ace70c86006f42b31396707bbe8b2d9e3481b0",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "f1d90bcb248e470f14eaf09d79fdee0d77c5b196f97209d2e40b827a89ffd979",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    },
    "amd64-freebsd" => {
      "static" => {
        "checksum" => "478de9db74f9fc9c32fd34c7c7ace70c86006f42b31396707bbe8b2d9e3481b0",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "f1d90bcb248e470f14eaf09d79fdee0d77c5b196f97209d2e40b827a89ffd979",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    }
  }
}.freeze
