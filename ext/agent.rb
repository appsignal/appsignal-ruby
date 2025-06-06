# frozen_string_literal: true

# DO NOT EDIT
# This is a generated file by the `rake publish` family of tasks in the
# appsignal-agent repository.
# Modifications to this file will be overwritten with the next agent release.

APPSIGNAL_AGENT_CONFIG = {
  "version" => "0.36.6",
  "mirrors" => [
    "https://d135dj0rjqvssy.cloudfront.net",
    "https://appsignal-agent-releases.global.ssl.fastly.net"
  ],
  "triples" => {
    "x86_64-darwin" => {
      "static" => {
        "checksum" => "b4a9453064663f969f2012d0fbbfad4566a35f3231d92d05c46b0e4fd15e62de",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "2d4db66cf830c9949acde834c70bd50581331cbe0919610fc09697334994015d",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "universal-darwin" => {
      "static" => {
        "checksum" => "b4a9453064663f969f2012d0fbbfad4566a35f3231d92d05c46b0e4fd15e62de",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "2d4db66cf830c9949acde834c70bd50581331cbe0919610fc09697334994015d",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-darwin" => {
      "static" => {
        "checksum" => "fc1245fca1445c2eb25f9e4f0dd5809f86eefa7e96ea87a227891ce76af81bfc",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "fae30a5dadbc0a3d8815055683a686ab96e9713a067778abdb99a25a7dc7d6f8",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm64-darwin" => {
      "static" => {
        "checksum" => "fc1245fca1445c2eb25f9e4f0dd5809f86eefa7e96ea87a227891ce76af81bfc",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "fae30a5dadbc0a3d8815055683a686ab96e9713a067778abdb99a25a7dc7d6f8",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm-darwin" => {
      "static" => {
        "checksum" => "fc1245fca1445c2eb25f9e4f0dd5809f86eefa7e96ea87a227891ce76af81bfc",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "fae30a5dadbc0a3d8815055683a686ab96e9713a067778abdb99a25a7dc7d6f8",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux" => {
      "static" => {
        "checksum" => "41f69ec7e2d15a552897eb22a745fb6df2589d8b53909155c16bd5fe5d830c71",
        "filename" => "appsignal-aarch64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "ad75ebf30a92261d4a3c5e15ed728f24da54c9b588dc71b840eba3f548096945",
        "filename" => "appsignal-aarch64-linux-all-dynamic.tar.gz"
      }
    },
    "i686-linux" => {
      "static" => {
        "checksum" => "abdaeca2c16362838ad0c81a36f55ae05638b9bc4cee647928e5c07c56582f6d",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "b2e7ce869405e9198d920c5ba94249a36ae4fa310666c8fcd250e6d7b7f8495f",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86-linux" => {
      "static" => {
        "checksum" => "abdaeca2c16362838ad0c81a36f55ae05638b9bc4cee647928e5c07c56582f6d",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "b2e7ce869405e9198d920c5ba94249a36ae4fa310666c8fcd250e6d7b7f8495f",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux" => {
      "static" => {
        "checksum" => "ca8bf1da8e0477027000ecad7b224244d3ff3217fa90652841567aa76bb0e2dc",
        "filename" => "appsignal-x86_64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "69dda126449371fc0cdbff3b381c3f40d98b2a8526ba900a21e8b7e1f5e293ad",
        "filename" => "appsignal-x86_64-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux-musl" => {
      "static" => {
        "checksum" => "dd9ea02fe7c0521a9761d94b232dd91d4fb2d39e73955872eb7b8344926d439d",
        "filename" => "appsignal-x86_64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "98aa3ef8d21998c35416760be24a202141f6b20718a09ebe449d1bdb58e78700",
        "filename" => "appsignal-x86_64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux-musl" => {
      "static" => {
        "checksum" => "dab51a719c468faa87232fd4c1c5ea1ad43a3ec0fcade99cafe1d82b039e3708",
        "filename" => "appsignal-aarch64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "b1ed4b3cfc02515c302b3ac1443f86dc34a8c9c27061a4a6587a7f050e2d8f3c",
        "filename" => "appsignal-aarch64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "x86_64-freebsd" => {
      "static" => {
        "checksum" => "115abdd9452f37037e7cc1f0e5b205e00317142a1d1d31d84c5729e6fba3cd46",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "5077cfcffaab249de505cba8a3e70f645e0a26d3ab26d4aac908226f9a818ea4",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    },
    "amd64-freebsd" => {
      "static" => {
        "checksum" => "115abdd9452f37037e7cc1f0e5b205e00317142a1d1d31d84c5729e6fba3cd46",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "5077cfcffaab249de505cba8a3e70f645e0a26d3ab26d4aac908226f9a818ea4",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    }
  }
}.freeze
