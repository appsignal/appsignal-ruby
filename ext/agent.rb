# frozen_string_literal: true

# DO NOT EDIT
# This is a generated file by the `rake publish` family of tasks in the
# appsignal-agent repository.
# Modifications to this file will be overwritten with the next agent release.

APPSIGNAL_AGENT_CONFIG = {
  "version" => "0.35.29",
  "mirrors" => [
    "https://d135dj0rjqvssy.cloudfront.net",
    "https://appsignal-agent-releases.global.ssl.fastly.net"
  ],
  "triples" => {
    "x86_64-darwin" => {
      "static" => {
        "checksum" => "880b317fc23d3cfa11ba88c80d11129bd02742b8b9c100bb038b66e73f85b723",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "0b9503e12862fb4824d78b1388bc4f51a9821f5c45ff78ae0782c2200632eac9",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "universal-darwin" => {
      "static" => {
        "checksum" => "880b317fc23d3cfa11ba88c80d11129bd02742b8b9c100bb038b66e73f85b723",
        "filename" => "appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "0b9503e12862fb4824d78b1388bc4f51a9821f5c45ff78ae0782c2200632eac9",
        "filename" => "appsignal-x86_64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-darwin" => {
      "static" => {
        "checksum" => "64b0107722401f5ee39eebec03b9c5a68a14967e8aa8806848df930f85a8afaf",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "3c1e8da7ce62cfd72b3f83c212baf8ddcf3998b8c37fdcb990d1fc9397488428",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm64-darwin" => {
      "static" => {
        "checksum" => "64b0107722401f5ee39eebec03b9c5a68a14967e8aa8806848df930f85a8afaf",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "3c1e8da7ce62cfd72b3f83c212baf8ddcf3998b8c37fdcb990d1fc9397488428",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "arm-darwin" => {
      "static" => {
        "checksum" => "64b0107722401f5ee39eebec03b9c5a68a14967e8aa8806848df930f85a8afaf",
        "filename" => "appsignal-aarch64-darwin-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "3c1e8da7ce62cfd72b3f83c212baf8ddcf3998b8c37fdcb990d1fc9397488428",
        "filename" => "appsignal-aarch64-darwin-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux" => {
      "static" => {
        "checksum" => "02dd40769daa5cde64dfee9e0931d0432c4ccffeb6c08197cccc454234fdae2c",
        "filename" => "appsignal-aarch64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "1eaeed41ec98cb930454944cf27d45e5bb35805d303503ea00f59dbaccce7c37",
        "filename" => "appsignal-aarch64-linux-all-dynamic.tar.gz"
      }
    },
    "i686-linux" => {
      "static" => {
        "checksum" => "4e19e1db93add17a71aaf2fd14ddf4cbd6913338f8ebeb0569baa59e154e8999",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "df508739e7f67824566e6388966c1f88df1b835abc519cb1f3c8297dd6ff1fe2",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86-linux" => {
      "static" => {
        "checksum" => "4e19e1db93add17a71aaf2fd14ddf4cbd6913338f8ebeb0569baa59e154e8999",
        "filename" => "appsignal-i686-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "df508739e7f67824566e6388966c1f88df1b835abc519cb1f3c8297dd6ff1fe2",
        "filename" => "appsignal-i686-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux" => {
      "static" => {
        "checksum" => "1150865e4a9b6d773a10702414b9b0b7cc69a72c0cbb17f5a01cebf40cabbcc4",
        "filename" => "appsignal-x86_64-linux-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "b17ed8c85171638f14d0ff3bca9d83894a9d2966da0a4554ba9b6cd1197a0a54",
        "filename" => "appsignal-x86_64-linux-all-dynamic.tar.gz"
      }
    },
    "x86_64-linux-musl" => {
      "static" => {
        "checksum" => "86fe06ca6dcc93e68a9c603c9087f15b0cef213f4df0eab6c0b495034045cde0",
        "filename" => "appsignal-x86_64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "6b68164b768fda589390d34f3c20ac7fe19c7a64a864af723fad52abf981492b",
        "filename" => "appsignal-x86_64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "aarch64-linux-musl" => {
      "static" => {
        "checksum" => "a3b2e4eb3a32408cbbc5b0a12b1d61322378ce0dc30edfb1c541a43d0c5306ff",
        "filename" => "appsignal-aarch64-linux-musl-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "72163a268416a7171e69bd68f3cf4b732989107eb25b9a910618cc66079a1c87",
        "filename" => "appsignal-aarch64-linux-musl-all-dynamic.tar.gz"
      }
    },
    "x86_64-freebsd" => {
      "static" => {
        "checksum" => "a4982fab5a7b4a4292bd0002e3bc571cbeced167c6a3e36f6c26e7898b3d38a7",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "0dd1afc8e0896b87ce76b65358806e0b89213ffb8727a50d926c987978c5e1ee",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    },
    "amd64-freebsd" => {
      "static" => {
        "checksum" => "a4982fab5a7b4a4292bd0002e3bc571cbeced167c6a3e36f6c26e7898b3d38a7",
        "filename" => "appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "dynamic" => {
        "checksum" => "0dd1afc8e0896b87ce76b65358806e0b89213ffb8727a50d926c987978c5e1ee",
        "filename" => "appsignal-x86_64-freebsd-all-dynamic.tar.gz"
      }
    }
  }
}.freeze
