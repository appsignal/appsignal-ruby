# frozen_string_literal: true

# DO NOT EDIT
# This is a generated file by the `rake publish` family of tasks in the
# appsignal-agent repository.
# Modifications to this file will be overwritten with the next agent release.

APPSIGNAL_AGENT_CONFIG = {
  "version" => "0.35.27",
  "mirrors" => [
    "https://d135dj0rjqvssy.cloudfront.net",
    "https://appsignal-agent-releases.global.ssl.fastly.net"
  ],
  "triples" => {
    "x86_64-darwin" => {
      "static" => {
        "checksum" => "466a8ded961424cef363e15db1ae281a5c8868de1e866054943b63800c52ee11",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "aa2b6da87b7b6f387513b95e5a1ecf883f3e64e1a5567f0c26143040373e905d",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "universal-darwin" => {
      "static" => {
        "checksum" => "466a8ded961424cef363e15db1ae281a5c8868de1e866054943b63800c52ee11",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "aa2b6da87b7b6f387513b95e5a1ecf883f3e64e1a5567f0c26143040373e905d",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-darwin" => {
      "static" => {
        "checksum" => "a775401a75dac8e643508cee6a5489945fc568085bd89d613dab579b08db6703",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "58da277cc5fcff0fc6efb54268aa9d07e69544b76d4b9bf85f0314130e3e31ff",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm64-darwin" => {
      "static" => {
        "checksum" => "a775401a75dac8e643508cee6a5489945fc568085bd89d613dab579b08db6703",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "58da277cc5fcff0fc6efb54268aa9d07e69544b76d4b9bf85f0314130e3e31ff",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm-darwin" => {
      "static" => {
        "checksum" => "a775401a75dac8e643508cee6a5489945fc568085bd89d613dab579b08db6703",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "58da277cc5fcff0fc6efb54268aa9d07e69544b76d4b9bf85f0314130e3e31ff",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux" => {
      "static" => {
        "checksum" => "d4d33982382b04f89ca7b1cdbe2ec364d7e505a53fe2b87ad4c33583f583d430",
        "filename" => "appsignal-aarch64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "990f2fdcde332b07a953c0e1106af8019be27d5be0abd4a5d28d0289996b9b60",
        "filename" => "appsignal-aarch64-linux-all-dynamic.tar.gz"
      }
    },
    "i686-linux" => {
      "static" => {
        "checksum" => "0ef6bf102929a6efbf3587310628d1321ea83987cb18f64ef7654162945c6216",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "22b1d3170b6180b30e8c25a1cdea17f2874320ed00dee42b67d6b1a0fd71770c",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86-linux" => {
      "static" => {
        "checksum" => "0ef6bf102929a6efbf3587310628d1321ea83987cb18f64ef7654162945c6216",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "22b1d3170b6180b30e8c25a1cdea17f2874320ed00dee42b67d6b1a0fd71770c",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux" => {
      "static" => {
        "checksum" => "4405619e2a536c153d99d80c20d137810e3cf410a8f6013ba88a49f0ff51f9ff",
        "filename" => "appsignal-x86_64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "b9717f4543e832040714c4b9c11c51b79a2ad48bff2cb501137821bf32db53b1",
        "filename" => "appsignal-x86_64-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux-musl" => {
      "static" => {
        "checksum" => "191aaa688289167912ac2269e6f0f16e893c9938b34153375658a2caae67a25b",
        "filename" => "appsignal-x86_64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "b075af5f5cffefe565d7ac7c574ceec55981cd667b4d544d7b10eb50c658bbb2",
        "filename" => "appsignal-x86_64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux-musl" => {
      "static" => {
        "checksum" => "f068b5d9aeca142766efe424d6e1c38cd79323bb22ff707efe75e13d56863b13",
        "filename" => "appsignal-aarch64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "f2aeefdb738dde746d693c1bb3cc38c78466a6828de5f42c59d54b4100560fd1",
        "filename" => "appsignal-aarch64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "x86_64-freebsd" => {
      "static" => {
        "checksum" => "93b26e0b1e9bb6bcf6ce862c8c7e95eb6b6f0a8be519012f84d47e48c24acead",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "4a44a947783bd685bdc25b93b204b4ede79ffee2b7dbc9c934f61baab61620d0",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    },
    "amd64-freebsd" => {
      "static" => {
        "checksum" => "93b26e0b1e9bb6bcf6ce862c8c7e95eb6b6f0a8be519012f84d47e48c24acead",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "4a44a947783bd685bdc25b93b204b4ede79ffee2b7dbc9c934f61baab61620d0",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    }
  }
}.freeze
