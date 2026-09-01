# frozen_string_literal: true

# DO NOT EDIT
# This is a generated file by the `rake publish` family of tasks in the
# appsignal-agent repository.
# Modifications to this file will be overwritten with the next agent release.

APPSIGNAL_AGENT_CONFIG = {
  "version" => "0.37.0",
  "mirrors" => [
    "https://d135dj0rjqvssy.cloudfront.net",
    "https://appsignal-agent-releases.global.ssl.fastly.net"
  ],
  "triples" => {
    "x86_64-darwin" => {
      "static" => {
        "checksum" => "1c05ef4cd4f0d0646bbc00a61568448cafd6c8cd23e152a4d7e22bab7e733cf1",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "0c74689a0bc204e0ce462c875f46ea458aa63705956f1adb9daa72dbce47e736",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "universal-darwin" => {
      "static" => {
        "checksum" => "1c05ef4cd4f0d0646bbc00a61568448cafd6c8cd23e152a4d7e22bab7e733cf1",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "0c74689a0bc204e0ce462c875f46ea458aa63705956f1adb9daa72dbce47e736",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-darwin" => {
      "static" => {
        "checksum" => "031d0f3c32302271274d1e602c9cecb2b037e9dd338001901ff4ed4d0e457075",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "5aadc22281991a97250bd6bf12dd5dd764ffc4da72301d745f86d63542159436",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm64-darwin" => {
      "static" => {
        "checksum" => "031d0f3c32302271274d1e602c9cecb2b037e9dd338001901ff4ed4d0e457075",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "5aadc22281991a97250bd6bf12dd5dd764ffc4da72301d745f86d63542159436",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm-darwin" => {
      "static" => {
        "checksum" => "031d0f3c32302271274d1e602c9cecb2b037e9dd338001901ff4ed4d0e457075",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "5aadc22281991a97250bd6bf12dd5dd764ffc4da72301d745f86d63542159436",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux" => {
      "static" => {
        "checksum" => "48499ed06fda433dc7347a4a3d23944d0bfb31604e5d7f52db0a0bbe437f8e03",
        "filename" => "appsignal-aarch64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "d943b05951cce5d797c0fe7aeacafc9b6870a0d72aa7869b9aa16f5add82fcc6",
        "filename" => "appsignal-aarch64-linux-all-dynamic.tar.gz"
      }
    },
    "i686-linux" => {
      "static" => {
        "checksum" => "41600ba4171cb8549ff9c8b675e9b4ef100eb7ef0a001a970964af04dc209738",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "ada062a08dc531421141330764e4a0b9a05b34b52b922c1c705ffbac604eb332",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86-linux" => {
      "static" => {
        "checksum" => "41600ba4171cb8549ff9c8b675e9b4ef100eb7ef0a001a970964af04dc209738",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "ada062a08dc531421141330764e4a0b9a05b34b52b922c1c705ffbac604eb332",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux" => {
      "static" => {
        "checksum" => "8240c494573360ad147aa56a973fe809bf1f3976383b8cd990fc0824e5554913",
        "filename" => "appsignal-x86_64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "ec07ea8188c3589c7c9a401d7555b51fdd052f07b05fc62e3801288493f85ca8",
        "filename" => "appsignal-x86_64-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux-musl" => {
      "static" => {
        "checksum" => "39de4602e300f701ed28748bd1c523bedf44f2d0f6241fffe370485185a895cc",
        "filename" => "appsignal-x86_64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "8a9fd74a6a7589b842a8297025656e7ccc995c9df40c09cf45b39382d3d4a507",
        "filename" => "appsignal-x86_64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux-musl" => {
      "static" => {
        "checksum" => "13fa41ad765a9c79f374dad4d131e7860afb8760c11508af1de982580798a3bc",
        "filename" => "appsignal-aarch64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "8193f5925818164390aac737d15a3d86706fce7aad81c4d5e84a3b0552b407a5",
        "filename" => "appsignal-aarch64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "x86_64-freebsd" => {
      "static" => {
        "checksum" => "c519b132c7a1de2a8dbb8c36d87fe91b4c0451d2c65d8bd4f44b748bb2ad2904",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "fb5ea3aac557543de74842d668c66ede00d125e1e86f601fa5ffe002edbd6c62",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    },
    "amd64-freebsd" => {
      "static" => {
        "checksum" => "c519b132c7a1de2a8dbb8c36d87fe91b4c0451d2c65d8bd4f44b748bb2ad2904",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "fb5ea3aac557543de74842d668c66ede00d125e1e86f601fa5ffe002edbd6c62",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    }
  }
}.freeze
