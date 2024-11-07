# frozen_string_literal: true

# DO NOT EDIT
# This is a generated file by the `rake publish` family of tasks in the
# appsignal-agent repository.
# Modifications to this file will be overwritten with the next agent release.

APPSIGNAL_AGENT_CONFIG = {
  "version" => "0.35.28",
  "mirrors" => [
    "https://d135dj0rjqvssy.cloudfront.net",
    "https://appsignal-agent-releases.global.ssl.fastly.net"
  ],
  "triples" => {
    "x86_64-darwin" => {
      "static" => {
        "checksum" => "8759daae4f842a7dcf370e521de8de9390b3883e09abe8b4f868b6827c855bb3",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "bf65784cd4b082db18f241f02e21472f7356b59c5be1a1ef19788ffdac82e737",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "universal-darwin" => {
      "static" => {
        "checksum" => "8759daae4f842a7dcf370e521de8de9390b3883e09abe8b4f868b6827c855bb3",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "bf65784cd4b082db18f241f02e21472f7356b59c5be1a1ef19788ffdac82e737",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-darwin" => {
      "static" => {
        "checksum" => "247551894b2195bb7e9cc6b52e8a42e10af0723b67f757d3eb84fe34791d0509",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "21941505aed9051c31883e29e3b2de1816ef881ae68dc30cb0fd39104b5fcd4f",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm64-darwin" => {
      "static" => {
        "checksum" => "247551894b2195bb7e9cc6b52e8a42e10af0723b67f757d3eb84fe34791d0509",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "21941505aed9051c31883e29e3b2de1816ef881ae68dc30cb0fd39104b5fcd4f",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm-darwin" => {
      "static" => {
        "checksum" => "247551894b2195bb7e9cc6b52e8a42e10af0723b67f757d3eb84fe34791d0509",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "21941505aed9051c31883e29e3b2de1816ef881ae68dc30cb0fd39104b5fcd4f",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux" => {
      "static" => {
        "checksum" => "02d62cfab5ab81faec40db6d80d47e53b2fca640026715697ab43f19539ace34",
        "filename" => "appsignal-aarch64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "8b580113f28781063be3538c8097c837ac85c3213c80d2597c00e32786921ef1",
        "filename" => "appsignal-aarch64-linux-all-dynamic.tar.gz"
      }
    },
    "i686-linux" => {
      "static" => {
        "checksum" => "d5771f360fbb24eb6d39459a910fcbb097904f8459a1735747dde3589c7d710d",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "03a066d55a5722802d053f8bdfdbe4bcb4ba9ee72b27d6a39aa62adad037f273",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86-linux" => {
      "static" => {
        "checksum" => "d5771f360fbb24eb6d39459a910fcbb097904f8459a1735747dde3589c7d710d",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "03a066d55a5722802d053f8bdfdbe4bcb4ba9ee72b27d6a39aa62adad037f273",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux" => {
      "static" => {
        "checksum" => "f3efd7973a0a4b5a0dca7ef23a896a866f011e70d90e2d22cd77c343ffbdf0c1",
        "filename" => "appsignal-x86_64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "0900dd8f79838943532db19876018d95065b851eeb5f01c15dfb227bce7a01d8",
        "filename" => "appsignal-x86_64-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux-musl" => {
      "static" => {
        "checksum" => "9e0cc593389e08527d2e62cc4389711a137511021fd59abd311da8ef5343aee6",
        "filename" => "appsignal-x86_64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "b4420a303780e8733387338dca5a0f7dce03c4e0ec95526ec108bc66f39970ab",
        "filename" => "appsignal-x86_64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux-musl" => {
      "static" => {
        "checksum" => "5112c3d0b22f27e6ed108d671ec2903f4cbe084c8d104a05bc946d88ccfed633",
        "filename" => "appsignal-aarch64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "f15aaacdb197b114113c9a382ab371623e49ed0593af8a7d3c7d84aa10b77556",
        "filename" => "appsignal-aarch64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "x86_64-freebsd" => {
      "static" => {
        "checksum" => "5d87cf82173f95440277b4565a58742c2843f0ddb17bf8f285023c294d1d30ad",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "9ba8d1c731212b23dccd76f22ad6979da160fe0d688f383acf8126c8922ecbdf",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    },
    "amd64-freebsd" => {
      "static" => {
        "checksum" => "5d87cf82173f95440277b4565a58742c2843f0ddb17bf8f285023c294d1d30ad",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "9ba8d1c731212b23dccd76f22ad6979da160fe0d688f383acf8126c8922ecbdf",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    }
  }
}.freeze
