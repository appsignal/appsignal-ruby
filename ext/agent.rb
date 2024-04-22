# frozen_string_literal: true

# DO NOT EDIT
# This is a generated file by the `rake ship` family of tasks in the
# appsignal-agent repository.
# Modifications to this file will be overwritten with the next agent release.

APPSIGNAL_AGENT_CONFIG = {
  "version" => "0.35.2",
  "mirrors" => [
    "https://appsignal-agent-releases.global.ssl.fastly.net",
    "https://d135dj0rjqvssy.cloudfront.net"
  ],
  "triples" => {
    "x86_64-darwin" => {
      "static" => {
        "checksum" => "4a01803fae744971e2da08a325acb88a5f79bf44cbde03456652affb91fa0817",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "843f6bfd798b7ae829c4a169f249a5576f01eb102755e1851f2901d4ddfff1b0",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "universal-darwin" => {
      "static" => {
        "checksum" => "4a01803fae744971e2da08a325acb88a5f79bf44cbde03456652affb91fa0817",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "843f6bfd798b7ae829c4a169f249a5576f01eb102755e1851f2901d4ddfff1b0",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-darwin" => {
      "static" => {
        "checksum" => "c80fa534a0f34d0056102ed5ec21cb558b714b17dc2a91f62fabdb992acc8a54",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "53139766b4a6459f6db2ef0e9175ab7828652594f32a885fe0d650bdd1748719",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm64-darwin" => {
      "static" => {
        "checksum" => "c80fa534a0f34d0056102ed5ec21cb558b714b17dc2a91f62fabdb992acc8a54",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "53139766b4a6459f6db2ef0e9175ab7828652594f32a885fe0d650bdd1748719",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm-darwin" => {
      "static" => {
        "checksum" => "c80fa534a0f34d0056102ed5ec21cb558b714b17dc2a91f62fabdb992acc8a54",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "53139766b4a6459f6db2ef0e9175ab7828652594f32a885fe0d650bdd1748719",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux" => {
      "static" => {
        "checksum" => "71236975f40316d67c2b0e797814d52a49df8c5941375c0aed81c6870d82f299",
        "filename" => "appsignal-aarch64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "b9dffb56bbf0f1fe5538e914c9a0124c10390ce88077351b1e47cb93efbce1e5",
        "filename" => "appsignal-aarch64-linux-all-dynamic.tar.gz"
      }
    },
    "i686-linux" => {
      "static" => {
        "checksum" => "00ab0d029ede31225b2d134cdfab1e2c75e15e96229ef9e89ac14f51b8329988",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "8a6aba576fc1c9ba419758e49d6d5fc9ffd636f983e160a7595871f09f382e9b",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86-linux" => {
      "static" => {
        "checksum" => "00ab0d029ede31225b2d134cdfab1e2c75e15e96229ef9e89ac14f51b8329988",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "8a6aba576fc1c9ba419758e49d6d5fc9ffd636f983e160a7595871f09f382e9b",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux" => {
      "static" => {
        "checksum" => "2e96245f692f47ee8fd12cca92b620baf79845ec920fb19b38612dd1cb051961",
        "filename" => "appsignal-x86_64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "c64e9903bddf0478ab9bbc316ce8ab46c0998173c922312fee527045e91554ad",
        "filename" => "appsignal-x86_64-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux-musl" => {
      "static" => {
        "checksum" => "a99ebcdf993cd740dc556de9fba6e7ce1c802704c290c4d8b842cb4dc971473a",
        "filename" => "appsignal-x86_64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "bfb583eebc82c2ae22f904a423df5af3cbf899225ffd8a3f96d0158985aa6e7c",
        "filename" => "appsignal-x86_64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux-musl" => {
      "static" => {
        "checksum" => "874542de2899dc7ef6d286f1cb719614877651c6cafc9f5ae73d37d1aa0e61da",
        "filename" => "appsignal-aarch64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "02f895487486732bce4cbbed251275a3fc4830a4e890c592f2e95559a5ca11d5",
        "filename" => "appsignal-aarch64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "x86_64-freebsd" => {
      "static" => {
        "checksum" => "f30c529ed4fffe4f0668bcb59881061b22050813d9d10acf5a4bf03f4547a51b",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "da6f4e31097ab2315b5bbffa8752284e40b535f4900057dc273a7bc7a23ac1ac",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    },
    "amd64-freebsd" => {
      "static" => {
        "checksum" => "f30c529ed4fffe4f0668bcb59881061b22050813d9d10acf5a4bf03f4547a51b",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "da6f4e31097ab2315b5bbffa8752284e40b535f4900057dc273a7bc7a23ac1ac",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    }
  }
}.freeze
