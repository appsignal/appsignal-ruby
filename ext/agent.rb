# frozen_string_literal: true

# DO NOT EDIT
# This is a generated file by the `rake publish` family of tasks in the
# appsignal-agent repository.
# Modifications to this file will be overwritten with the next agent release.

APPSIGNAL_AGENT_CONFIG = {
  "version" => "0.37.2",
  "mirrors" => [
    "https://d135dj0rjqvssy.cloudfront.net",
    "https://appsignal-agent-releases.global.ssl.fastly.net"
  ],
  "triples" => {
    "x86_64-darwin" => {
      "static" => {
        "checksum" => "04acbec47f4f5955ff51295aa3f3e727c89a42fcfc99ac572225ec4285ee21ed",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "d3b4058dff863489b84edbe18da17c5c1ad5a4424729dd42b398c7adba1ac7ad",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "universal-darwin" => {
      "static" => {
        "checksum" => "04acbec47f4f5955ff51295aa3f3e727c89a42fcfc99ac572225ec4285ee21ed",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "d3b4058dff863489b84edbe18da17c5c1ad5a4424729dd42b398c7adba1ac7ad",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-darwin" => {
      "static" => {
        "checksum" => "330cd3d0b0c316ac4cbdfb237930a29e67205c12d5bf7bb1da51213eea97f18f",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "391547450b024a76dfef91e9293d2617d29f87a706675b38661256b244e0d921",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm64-darwin" => {
      "static" => {
        "checksum" => "330cd3d0b0c316ac4cbdfb237930a29e67205c12d5bf7bb1da51213eea97f18f",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "391547450b024a76dfef91e9293d2617d29f87a706675b38661256b244e0d921",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm-darwin" => {
      "static" => {
        "checksum" => "330cd3d0b0c316ac4cbdfb237930a29e67205c12d5bf7bb1da51213eea97f18f",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "391547450b024a76dfef91e9293d2617d29f87a706675b38661256b244e0d921",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux" => {
      "static" => {
        "checksum" => "174eba16ca19747fc9c68acae722d65d194c90a9ba9fbdb51741d770b42ddb6d",
        "filename" => "appsignal-aarch64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "149fa1991ab35a075c26498f51a6bb27bd64d125233d3cf4e6f5dba0f31c6caf",
        "filename" => "appsignal-aarch64-linux-all-dynamic.tar.gz"
      }
    },
    "i686-linux" => {
      "static" => {
        "checksum" => "0da7b25472e1bf40516c9257f5507cbf2024db7c4aff796528ac114bd409d059",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "bad8a046c9ad6030d33541346d2afeb452a4a8bb9e011ad542ec3ccb35ce5146",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86-linux" => {
      "static" => {
        "checksum" => "0da7b25472e1bf40516c9257f5507cbf2024db7c4aff796528ac114bd409d059",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "bad8a046c9ad6030d33541346d2afeb452a4a8bb9e011ad542ec3ccb35ce5146",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux" => {
      "static" => {
        "checksum" => "43ae7bd5492990fcec90d08ab37e5a1ec9cca3f148f93d91a4c8b31b6accdf50",
        "filename" => "appsignal-x86_64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "ae3493fd0da4fad044cdf54adff3e5009e20d8212c7ad7149a9b0031a13be8da",
        "filename" => "appsignal-x86_64-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux-musl" => {
      "static" => {
        "checksum" => "a1cf987b2f29548071c7ee6a222158d67ab1451976d5db4b999e5e7156ce10f2",
        "filename" => "appsignal-x86_64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "fa6a84a6a86649bc9fb71e165eaac11149f97059ad5dbab310032a6359669611",
        "filename" => "appsignal-x86_64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux-musl" => {
      "static" => {
        "checksum" => "43b1e51d848a98cb9bbd1db32105369e103eaeae2ade9b365de5218af1f72c97",
        "filename" => "appsignal-aarch64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "3652fd6b0a823d316ca511594935d59106c2e22a2729865a55827ec50e69c7c7",
        "filename" => "appsignal-aarch64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "x86_64-freebsd" => {
      "static" => {
        "checksum" => "fe7011fc6874a8a9bd32bd24c4029f41261fbcfcabad400a758da0e4129c0b58",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "5b3c77880c665d72d8410cedf4677b50bfd74cfda6ade3188024cc166f37387b",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    },
    "amd64-freebsd" => {
      "static" => {
        "checksum" => "fe7011fc6874a8a9bd32bd24c4029f41261fbcfcabad400a758da0e4129c0b58",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "5b3c77880c665d72d8410cedf4677b50bfd74cfda6ade3188024cc166f37387b",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    }
  }
}.freeze
