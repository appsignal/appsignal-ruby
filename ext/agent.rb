# frozen_string_literal: true

# DO NOT EDIT
# This is a generated file by the `rake publish` family of tasks in the
# appsignal-agent repository.
# Modifications to this file will be overwritten with the next agent release.

APPSIGNAL_AGENT_CONFIG = {
  "version" => "0.37.5",
  "mirrors" => [
    "https://d135dj0rjqvssy.cloudfront.net",
    "https://appsignal-agent-releases.global.ssl.fastly.net"
  ],
  "triples" => {
    "x86_64-darwin" => {
      "static" => {
        "checksum" => "0c5f9fd85bf0a2468862c8a591e40120e346cee18f2240a46b7bcce0d880ea84",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "bc4845f14246bf775881c290b29e4887e0422edf2877a0df66417af48577bc60",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "universal-darwin" => {
      "static" => {
        "checksum" => "0c5f9fd85bf0a2468862c8a591e40120e346cee18f2240a46b7bcce0d880ea84",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "bc4845f14246bf775881c290b29e4887e0422edf2877a0df66417af48577bc60",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-darwin" => {
      "static" => {
        "checksum" => "844b7e189522b5ffee6370e5dbff2a687de5b4c2e34f67a638290a2e40dd0ec3",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "e69f3f923aeec06e45bf2263afa3390b561528dc129be581cba047ec7545829f",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm64-darwin" => {
      "static" => {
        "checksum" => "844b7e189522b5ffee6370e5dbff2a687de5b4c2e34f67a638290a2e40dd0ec3",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "e69f3f923aeec06e45bf2263afa3390b561528dc129be581cba047ec7545829f",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm-darwin" => {
      "static" => {
        "checksum" => "844b7e189522b5ffee6370e5dbff2a687de5b4c2e34f67a638290a2e40dd0ec3",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "e69f3f923aeec06e45bf2263afa3390b561528dc129be581cba047ec7545829f",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux" => {
      "static" => {
        "checksum" => "3644566bc411f8f4c9937e53eccdd7bbea4545ddcc8a93db0158c6174f21a399",
        "filename" => "appsignal-aarch64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "91fc23f738f51ce12992f2833bc84f82ad42a4d74876cd6b67849de4df261db8",
        "filename" => "appsignal-aarch64-linux-all-dynamic.tar.gz"
      }
    },
    "i686-linux" => {
      "static" => {
        "checksum" => "29d534d174d955e0d86c572f1e9ce0ee7c9d9baa98d9f472ff501a79d1bc7dbd",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "bac6a565f6cc2031422f6dcd19c9b6af8d4e2c98d867fb2f2dea9eb9d2a0fbf3",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86-linux" => {
      "static" => {
        "checksum" => "29d534d174d955e0d86c572f1e9ce0ee7c9d9baa98d9f472ff501a79d1bc7dbd",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "bac6a565f6cc2031422f6dcd19c9b6af8d4e2c98d867fb2f2dea9eb9d2a0fbf3",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux" => {
      "static" => {
        "checksum" => "ba12a448ba337bfecf2a8dd2e67804f273c460973a2f191c87e26e612b7edb7c",
        "filename" => "appsignal-x86_64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "dc673d9935bf99ea9dd85bd25212f0253de9790a09010cb58bea80ee04d67c5f",
        "filename" => "appsignal-x86_64-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux-musl" => {
      "static" => {
        "checksum" => "4331b313e952e2e54a8d217b08f2ff9d704a5581935617e1bfaff20f0680caef",
        "filename" => "appsignal-x86_64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "88d62670845fd020f3cdce345f48911fe9da2d8be7aa3ca439ce352dd22d427d",
        "filename" => "appsignal-x86_64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux-musl" => {
      "static" => {
        "checksum" => "364cc397eddf43049c87fc87a385d9cbc7722cdd11ffa2f5052c24e19e0e5d69",
        "filename" => "appsignal-aarch64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "c707f5a648a35e2ed1eecbb8ac7a05339e404a9da5301e3920712983c200b904",
        "filename" => "appsignal-aarch64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "x86_64-freebsd" => {
      "static" => {
        "checksum" => "f1ece6d2f2b0a36a86a4a48059deea89b3ae909c0aafc659372127f072d036ec",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "d2d620e3ca6a466ccdd556a7736e1645070e2b326ede41eaf7d34ff38de88d73",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    },
    "amd64-freebsd" => {
      "static" => {
        "checksum" => "f1ece6d2f2b0a36a86a4a48059deea89b3ae909c0aafc659372127f072d036ec",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "d2d620e3ca6a466ccdd556a7736e1645070e2b326ede41eaf7d34ff38de88d73",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    }
  }
}.freeze
