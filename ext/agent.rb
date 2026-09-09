# frozen_string_literal: true

# DO NOT EDIT
# This is a generated file by the `rake publish` family of tasks in the
# appsignal-agent repository.
# Modifications to this file will be overwritten with the next agent release.

APPSIGNAL_AGENT_CONFIG = {
  "version" => "0.37.1",
  "mirrors" => [
    "https://d135dj0rjqvssy.cloudfront.net",
    "https://appsignal-agent-releases.global.ssl.fastly.net"
  ],
  "triples" => {
    "x86_64-darwin" => {
      "static" => {
        "checksum" => "a29834f6a305a0baedbf5bd3f25c28feca45b3a175029d655ece7224515c206a",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "7450ed4679d7ca425d7fb7563931a9ca73365ac03ac62ace1880d0a5de2fe06d",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "universal-darwin" => {
      "static" => {
        "checksum" => "a29834f6a305a0baedbf5bd3f25c28feca45b3a175029d655ece7224515c206a",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "7450ed4679d7ca425d7fb7563931a9ca73365ac03ac62ace1880d0a5de2fe06d",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-darwin" => {
      "static" => {
        "checksum" => "53198c2f10fb56565ceece6632ec0cd38f30e7fef3df79094f11381f4b07f8a6",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "18fd2861c72fdb1ed5261cad90667923d0b2299ebd3511114d10416ecbd9998c",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm64-darwin" => {
      "static" => {
        "checksum" => "53198c2f10fb56565ceece6632ec0cd38f30e7fef3df79094f11381f4b07f8a6",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "18fd2861c72fdb1ed5261cad90667923d0b2299ebd3511114d10416ecbd9998c",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm-darwin" => {
      "static" => {
        "checksum" => "53198c2f10fb56565ceece6632ec0cd38f30e7fef3df79094f11381f4b07f8a6",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "18fd2861c72fdb1ed5261cad90667923d0b2299ebd3511114d10416ecbd9998c",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux" => {
      "static" => {
        "checksum" => "64fc4b0b48d780eb6721421a4d2ef3e4b94ee763266ad5a2768acdf3d9feadd7",
        "filename" => "appsignal-aarch64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "816c9b77f8782074fd04c71d094d6c8b6127ab3f501303cb80e22a31334b876c",
        "filename" => "appsignal-aarch64-linux-all-dynamic.tar.gz"
      }
    },
    "i686-linux" => {
      "static" => {
        "checksum" => "ea6544e43502d0ec49a708343483244a5ec457ae4c89752a295b238c3e62440c",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "8e40de0254d822f58610c00a047fdd34753d71c2c2f9c9e75afb228c4768857a",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86-linux" => {
      "static" => {
        "checksum" => "ea6544e43502d0ec49a708343483244a5ec457ae4c89752a295b238c3e62440c",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "8e40de0254d822f58610c00a047fdd34753d71c2c2f9c9e75afb228c4768857a",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux" => {
      "static" => {
        "checksum" => "bc04fc8691b8950d20776646117fd7a217a3267d4eac14b2c5f446ed8f9fcf99",
        "filename" => "appsignal-x86_64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "fe86688bd2ea0ad5cf6df1c71d7b041c375e5192c572b4bac540c7c36576ba1a",
        "filename" => "appsignal-x86_64-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux-musl" => {
      "static" => {
        "checksum" => "5cd6d3f106d6e34ad6558d5191241860345dfd3e0ad9daaa798c0781e17c142a",
        "filename" => "appsignal-x86_64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "3fa17e5a1e325842f89f14ddfbc48dd7286724a765859c073475633726364f4e",
        "filename" => "appsignal-x86_64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux-musl" => {
      "static" => {
        "checksum" => "86c3c6356cac89c4030e427915c3aad7ea804278835bd4a5cc75ebbdd18f5dbd",
        "filename" => "appsignal-aarch64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "66c5e30dad3f804261953c9a0ad7c15ef183163fe863894f524ea9bb34b6c9a0",
        "filename" => "appsignal-aarch64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "x86_64-freebsd" => {
      "static" => {
        "checksum" => "0428134ff69b924900b4cda8d16b181870ef4eced5cb501e9ac2a952f9c52580",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "90869b3bfe783dfcccef58814d7cd8785161ad9b6b552fd2de9a43ce8bd2bae5",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    },
    "amd64-freebsd" => {
      "static" => {
        "checksum" => "0428134ff69b924900b4cda8d16b181870ef4eced5cb501e9ac2a952f9c52580",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "90869b3bfe783dfcccef58814d7cd8785161ad9b6b552fd2de9a43ce8bd2bae5",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    }
  }
}.freeze
