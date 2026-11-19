import Config

config :life_core,
  workers: [
    %{
      id: "rust-01",
      language: :rust,
      executable: "../workers/rus/target/release/life-rust-worker.exe"
    },
    %{
      id: "go-01",
      language: :go,
      executable: "../workers/go/worker"
    },
    %{
      id: "python-01",
      language: :python,
      executable: "../workers/python/worker"
    }
  ]
