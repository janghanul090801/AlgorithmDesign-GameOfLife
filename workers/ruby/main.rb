require "json"

CellJob = Struct.new(
  :job_type,
  :id,
  :generation,
  :x,
  :y,
  :current,
  :board,
  keyword_init: true
)

CellResult = Struct.new(
  :result_type,
  :job_id,
  :generation,
  :x,
  :y,
  :alive,
  keyword_init: true
)

def count_neighbors(board, x, y)
  count = 0

  (-1..1).each do |dy|
    (-1..1).each do |dx|
      next if dx == 0 && dy == 0

      nx = x + dx
      ny = y + dy

      next if nx < 0 ||
              ny < 0 ||
              nx >= board["width"] ||
              ny >= board["height"]

      count += 1 if board["cells"][ny][nx]
    end
  end

  count
end

def calculate(current, neighbors)
  return true if current && (neighbors == 2 || neighbors == 3)
  return true if !current && neighbors == 3

  false
end

STDIN.each_line do |line|
  line = line.strip

  next if line.empty?

  begin
    job = JSON.parse(line)
  rescue JSON::ParserError => e
    STDERR.puts "failed to decode job: #{e.message}"
    next
  end

  next unless job["type"] == "cell"

  board = job["board"]

  neighbor_count = count_neighbors(
    board,
    job["x"],
    job["y"]
  )

  alive = calculate(
    job["current"],
    neighbor_count
  )

  result = {
    "type" => "result",
    "job_id" => job["id"],
    "generation" => job["generation"],
    "x" => job["x"],
    "y" => job["y"],
    "alive" => alive
  }

  puts JSON.generate(result)
  STDOUT.flush
end