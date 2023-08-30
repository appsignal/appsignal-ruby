# frozen_string_literal: true

# DO NOT EDIT
# This is a generated file by the `rake ship` family of tasks in the
# appsignal-agent repository.
# Modifications to this file will be overwritten with the next agent release.

APPSIGNAL_AGENT_CONFIG = {
  "version" => "6133900",
  "mirrors" => [
    "https://appsignal-agent-releases.global.ssl.fastly.net",
    "https://d135dj0rjqvssy.cloudfront.net"
  ],
  "triples" => {
    "x86_64-darwin" => {
      "static" => {
        "checksum" => "19cfea536fc6c4a8fe335a26d14ce955b422c23217902642f95d7df670152238",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "f5c4b66b45faac47473befdbe286a037d8fca9386339b00f59be9e9505d15b13",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "universal-darwin" => {
      "static" => {
        "checksum" => "19cfea536fc6c4a8fe335a26d14ce955b422c23217902642f95d7df670152238",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "f5c4b66b45faac47473befdbe286a037d8fca9386339b00f59be9e9505d15b13",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-darwin" => {
      "static" => {
        "checksum" => "4fa0dbccba79f70edc6844a86bfd047ccdd612d752b65aff46fe0e21d8a610ea",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "f86e88647be6c64f0f1f56b1ac15e0e4453c7e4a6c997fd5e510cf459c572a57",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm64-darwin" => {
      "static" => {
        "checksum" => "4fa0dbccba79f70edc6844a86bfd047ccdd612d752b65aff46fe0e21d8a610ea",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "f86e88647be6c64f0f1f56b1ac15e0e4453c7e4a6c997fd5e510cf459c572a57",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm-darwin" => {
      "static" => {
        "checksum" => "4fa0dbccba79f70edc6844a86bfd047ccdd612d752b65aff46fe0e21d8a610ea",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "f86e88647be6c64f0f1f56b1ac15e0e4453c7e4a6c997fd5e510cf459c572a57",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux" => {
      "static" => {
        "checksum" => "cdd75637940fcfd369b569e873048c7d37a3844d9d31d783e4459b375b78ee0e",
        "filename" => "appsignal-aarch64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "99b52c29d497d63f02a4ff7162152641b51e7ecd292d07f0330e7d4f3abc8075",
        "filename" => "appsignal-aarch64-linux-all-dynamic.tar.gz"
      }
    },
    "i686-linux" => {
      "static" => {
        "checksum" => "a9374d1fd4baae84f1c4a74957cbb8c919b29ae2ab05a571ff75b9ca483717ab",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "d643c72add6fe1054faff034101cf5a2676a169c7bff479f3d79e71875598b8a",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86-linux" => {
      "static" => {
        "checksum" => "a9374d1fd4baae84f1c4a74957cbb8c919b29ae2ab05a571ff75b9ca483717ab",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "d643c72add6fe1054faff034101cf5a2676a169c7bff479f3d79e71875598b8a",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux" => {
      "static" => {
        "checksum" => "bd625ed84100d0632b298ac602b152463628c41afe56a8621745cdae626f8413",
        "filename" => "appsignal-x86_64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "0daa644acfee46848282ad733b175e4994e7faf64c8bc046d2efff2b8fc1afdd",
        "filename" => "appsignal-x86_64-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux-musl" => {
      "static" => {
        "checksum" => "7988c4a2a6ba5d59be2186ce9bf51ab50b6537a60888b08c8e9066172516e59d",
        "filename" => "appsignal-x86_64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "93e47c9400ddae42a8cd2b80c09c9134ee96a76bf622c3ad5d53b776fec1a3f0",
        "filename" => "appsignal-x86_64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux-musl" => {
      "static" => {
        "checksum" => "8e5fe2a8bc4cb7de4ba7d61fec48f15aa0cd580050f67752f07625853636eb16",
        "filename" => "appsignal-aarch64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "01f993b3320f0377ef9f652bb215ce268da208f46a6f59ad0c0e71f57257b4ef",
        "filename" => "appsignal-aarch64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "x86_64-freebsd" => {
      "static" => {
        "checksum" => "09e21821eb98ad6afdb5d3708b67ea25799aedbee2ccb0d566b99d9c5703cb1e",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "e77592de9dd7ff41efb6c1d2d88e06fa7b663e9ff009392bb971b1333e0f28d7",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    },
    "amd64-freebsd" => {
      "static" => {
        "checksum" => "09e21821eb98ad6afdb5d3708b67ea25799aedbee2ccb0d566b99d9c5703cb1e",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "e77592de9dd7ff41efb6c1d2d88e06fa7b663e9ff009392bb971b1333e0f28d7",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    }
  }
}.freeze
