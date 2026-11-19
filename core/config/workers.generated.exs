import Config

config :life_core,
  workers: [
    %{
      id: "go",
      language: :go,
      executable: "../workers/go/go.exe"
    },
    %{
      id: "rust",
      language: :rust,
      executable: "../workers/rust/target/release/life-rust-worker.exe"
    }
  ]
