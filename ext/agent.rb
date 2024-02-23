# frozen_string_literal: true

# DO NOT EDIT
# This is a generated file by the `rake ship` family of tasks in the
# appsignal-agent repository.
# Modifications to this file will be overwritten with the next agent release.

APPSIGNAL_AGENT_CONFIG = {
  "version" => "0.33.2",
  "mirrors" => [
    "https://appsignal-agent-releases.global.ssl.fastly.net",
    "https://d135dj0rjqvssy.cloudfront.net"
  ],
  "triples" => {
    "x86_64-darwin" => {
      "static" => {
        "checksum" => "0864691f001133fa479b34b00a682e76f374c40c161e7715756a3c036e3c8798",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "5141528c4293e4bd619107ae79afc8e07fdc8b33835899c5cf3f82ab3d31de8f",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "universal-darwin" => {
      "static" => {
        "checksum" => "0864691f001133fa479b34b00a682e76f374c40c161e7715756a3c036e3c8798",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "5141528c4293e4bd619107ae79afc8e07fdc8b33835899c5cf3f82ab3d31de8f",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-darwin" => {
      "static" => {
        "checksum" => "13506e5911523e7107a8cb714e18b3bcb690f3eeef88bf9aff54777ba540fdc4",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "9d4deef17f42dc54981344a5af6b872e06dbd3d317be68b6abeb2403ffd65e23",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm64-darwin" => {
      "static" => {
        "checksum" => "13506e5911523e7107a8cb714e18b3bcb690f3eeef88bf9aff54777ba540fdc4",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "9d4deef17f42dc54981344a5af6b872e06dbd3d317be68b6abeb2403ffd65e23",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm-darwin" => {
      "static" => {
        "checksum" => "13506e5911523e7107a8cb714e18b3bcb690f3eeef88bf9aff54777ba540fdc4",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "9d4deef17f42dc54981344a5af6b872e06dbd3d317be68b6abeb2403ffd65e23",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux" => {
      "static" => {
        "checksum" => "76702b5755d5bb45cc05df17dd38389b7e20e105a52324120a45ae1b481c7881",
        "filename" => "appsignal-aarch64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "bf518ce2cb4a9041fe819b6bf43e1bc793fe52b3e73527687d7812618c8e7407",
        "filename" => "appsignal-aarch64-linux-all-dynamic.tar.gz"
      }
    },
    "i686-linux" => {
      "static" => {
        "checksum" => "22cbda11a8d801d75e9394033f5cf28f0ddcff66a2138720f827441bdcf919c2",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "157492663e434421499f9cc0b510178387c8968e53bdc6e216db374b86d5c3dc",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86-linux" => {
      "static" => {
        "checksum" => "22cbda11a8d801d75e9394033f5cf28f0ddcff66a2138720f827441bdcf919c2",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "157492663e434421499f9cc0b510178387c8968e53bdc6e216db374b86d5c3dc",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux" => {
      "static" => {
        "checksum" => "8ff0b1d7bf0cfc1c66e918545a9ab5c29be35c371cde48f64a01c725290599ed",
        "filename" => "appsignal-x86_64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "a186c18536c3b7ec4802e852a62154cc976dcb5f554c3d0d8472d5cd7131b02b",
        "filename" => "appsignal-x86_64-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux-musl" => {
      "static" => {
        "checksum" => "a5e0af3e5e1ad908792e79c7c46b59119272e9836e5ea96791c78e3cb12ed132",
        "filename" => "appsignal-x86_64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "17c108a83dff86b2531bf7f348481bb31ece53b4cc62615ca0a34332c0df2970",
        "filename" => "appsignal-x86_64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux-musl" => {
      "static" => {
        "checksum" => "92460560115d540a8140cbc360bd98beba8477e8a73eafd20ee611543b4528df",
        "filename" => "appsignal-aarch64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "d4749b10a1803080e0b1b0d8f95ef9d1fef0aa694fa0fc405df97812937d8e7c",
        "filename" => "appsignal-aarch64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "x86_64-freebsd" => {
      "static" => {
        "checksum" => "8d8733c2adc0f750553be11b5e54fd614b13207be67863d95c57e4739021a92f",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "8a9cbdc645b3833766458a252c2a8fefda76c62fceee8be795b286d65cc513c6",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    },
    "amd64-freebsd" => {
      "static" => {
        "checksum" => "8d8733c2adc0f750553be11b5e54fd614b13207be67863d95c57e4739021a92f",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "8a9cbdc645b3833766458a252c2a8fefda76c62fceee8be795b286d65cc513c6",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    }
  }
}.freeze
