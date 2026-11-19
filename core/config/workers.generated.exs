import Config

config :life_core,
  workers: [
    %{
      id: "go",
      language: :go,
      command: ["./go.exe"],
      cd: "../workers/go"
    },
    %{
      id: "java",
      language: :java,
      command: ["./.jdk/bin/java.exe", "-jar", "app/build/libs/app.jar"],
      cd: "../workers/java"
    },
    %{
      id: "ruby",
      language: :ruby,
      command: ["ruby", "./main.rb"],
      cd: "../workers/ruby"
    },
    %{
      id: "rust",
      language: :rust,
      command: ["./target/release/life-rust-worker.exe"],
      cd: "../workers/rust"
    }
  ]
