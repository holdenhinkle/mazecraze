require 'pry'
require 'yaml'
require 'fileutils'
require 'json'

class Boards
  attr_reader :all_boards

  def initialize(boards)
    @all_boards = {}
    create_boards(boards)
  end

  private

  def create_boards(boards)
    boards.each do |board|
      @all_boards["board_#{board[:x]}x#{board[:y]}".to_sym] = Board.new(board)
    end
  end
end

class Board
  attr_reader :size, :num_starts, :num_barriers, :grids

  def initialize(board)
    @size = board[:x] * board[:y]
    @num_starts = board[:num_starts]
    @num_barriers = board[:num_barriers]
    @grids = create_grids(board)
  end

  private

  def create_grids(board)
    counter = starting_file_number(board[:level]) + 1
    file_path = permutations(layout)
    File.open(file_path, "r").each_line do |grid_layout|
      grid = Grid.new(board, JSON.parse(grid_layout))
      next unless grid.valid?
      save_grid!(grid, counter)
      counter += 1
    end
    FileUtils.rm(file_path)
  end

  def starting_file_number(level)
    largest_number = 0
    Dir[File.join(data_path, "/levels/level_#{level}/*")].each do |f|
      number = f.match(/\d+.yml/).to_s.match(/\d+/).to_s.to_i
      largest_number = number if number > largest_number
    end
    largest_number
  end

  def layout
    grid = []
    size.times do
      grid << if count_makers(grid, 's') != num_starts
                format_start_marker(grid)
              elsif count_makers(grid, 'f') != num_starts
                format_finish_marker(grid)
              elsif grid.count('b') != num_barriers
                'b'
              else
                'n'
              end
    end
    grid
  end

  def each_permutation(layout)
    layout.permutation { |permutation| yield(permutation) }
  end

  def permutations(layout)
    file_path = File.join(data_path, "/levels/grid_scratch_file.txt")
    FileUtils.mkdir_p(File.dirname(file_path)) unless File.directory?(File.dirname(file_path))
    File.new(file_path, "w") unless File.exist?(file_path)

    each_permutation(layout) do |permutation|
      next if grid_layout_exists?(file_path, permutation)
      File.open(file_path, "a") do |f|
        f.write(permutation)
        f.write("\n")
      end
    end
    file_path
  end

  def grid_layout_exists?(file_path, permutation)
    File.foreach(file_path).any? do |line|
      line.include?(permutation.to_s)
    end
  end

  def count_makers(grid, marker)
    grid.count { |square| square.match(Regexp.new(Regexp.escape(marker))) }
  end

  # refactor - combine this method and the one below
  def format_start_marker(grid)
    s_counter = 0
    grid.each { |marker| s_counter += 1 if marker.match(/s/) }
    "s#{s_counter + 1}"
  end

  # refactor - combine this method and the one above
  def format_finish_marker(grid)
    s_counter = 0
    grid.each { |marker| s_counter += 1 if marker.match(/f/) }
    "f#{s_counter + 1}"
  end

  def save_grid!(grid, index)
    directory = "/levels/level_#{grid.level}"
    directory_path = File.join(data_path, directory)
    FileUtils.mkdir_p(directory_path) unless File.directory?(directory_path)
    File.open(File.join(directory_path, "#{index}.yml"), "w") do |file|
      file.write(grid.to_yaml)
    end
  end

  def data_path
    File.expand_path("../data", __FILE__)
  end
end

module Solvable
  def each_path(results)
    current_attempt = Marshal.load(Marshal.dump(results.shift))
    current_square = current_attempt[:path].last
    yield(current_attempt, next_square_up(current_square)) if next_square_up(current_square) && squares[next_square_up(current_square)].not_taken?
    yield(current_attempt, next_square_right(current_square)) if next_square_right(current_square) && squares[next_square_right(current_square)].not_taken?
    yield(current_attempt, next_square_down(current_square)) if next_square_down(current_square) && squares[next_square_down(current_square)].not_taken?
    yield(current_attempt, next_square_left(current_square)) if next_square_left(current_square) && squares[next_square_left(current_square)].not_taken?
  end

  def solve

    # **** RESULTS NEVER BECOME EMPTY! ****
    solutions = []
    results = [{ path: [start_square], grid: self }]
    until results.empty?
      each_path(results) do |current_attempt, next_square|
        path_copy = Marshal.load(Marshal.dump(current_attempt[:path])).push(next_square)
        grid_copy = Marshal.load(Marshal.dump(current_attempt[:grid]))
        grid_copy.squares[next_square].taken!
        if grid_copy.squares[next_square].finish_square? && grid_copy.all_squares_taken?
          solutions << path_copy
        elsif grid_copy.squares[next_square].normal_square?
          results << { path: path_copy, grid: grid_copy }
        end
      end
    end
    p solutions
    solutions
  end
end

class Grid
  include Solvable

  attr_reader :squares, :x, :y, :solution, :level

  def initialize(board, grid)
    @squares = create_grid(grid)
    @x = board[:x]
    @y = board[:y]
    binding.pry
    # @solution = solve
    @level = board[:level]
  end

  def valid?
    valid_finish_squares?
    # one_solution?
  end

  def one_solution?
    solution.size == 1
  end

  def all_squares_taken?
    squares.all?(&:taken?)
  end

  private

  def create_grid(grid)
    grid.map do |square|
      if square.match(/s/)
        Square.new("start_#{square.match(/\d/)}".to_sym, :taken)
      elsif square.match(/f/)
        Square.new("finish_#{square.match(/\d/)}".to_sym, :not_taken)
      elsif square == 'b'
        Square.new(:barrier, :taken)
      elsif square == 'n'
        Square.new(:normal, :not_taken)
      end
    end
  end

  def size
    squares.count
  end

  # Refactor - combine below
  def start_squares
    results = {}
    squares.each_with_index do |square, index| 
      results[square.type] = index if square.type.match(/s/)
    end
    results
  end

  # Refactor - combine - above
  def finish_squares
    results = {}
    squares.each_with_index do |square, index|
      results[square.type] = index if square.type.match(/f/)
    end
    results
  end

  def valid_finish_squares?
    finish_squares.all? { |_, index| valid_finish_square?(index) }
  end

  def valid_finish_square?(square)
    return false if connected_to_start_square?(square)
    return false if connected_to_more_than_one_normal_square?(square)
    true
  end

  def connected_to_start_square?(square)
    surrounding_squares(square).any? { |sq| squares[sq].start_square? }
  end

  def connected_to_more_than_one_normal_square?(square)
    connections = 0
    connections += 1 if normal_square_above?(square)
    connections += 1 if normal_square_right?(square)
    connections += 1 if normal_square_below?(square)
    connections += 1 if normal_square_left?(square)
    connections > 1
  end

  def start_square
    squares.each_with_index do |square, index|
      return index if square.start_square?
    end
  end

  # Refactor
  def normal_square_above?(square)
    next_square = next_square_up(square)
    if next_square
      return squares[next_square].normal_square? && squares[next_square].not_taken?
    end
    false
  end

  # Refactor
  def normal_square_right?(square)
    next_square = next_square_right(square)
    if next_square
      return squares[next_square].normal_square? && squares[next_square].not_taken?
    end
    false
  end

  # Refactor
  def normal_square_below?(square)
    next_square = next_square_down(square)
    if next_square
      return squares[next_square].normal_square? && squares[next_square].not_taken?
    end
    false
  end

  # Refactor
  def normal_square_left?(square)
    next_square = next_square_left(square)
    if next_square
      return squares[next_square].normal_square? && squares[next_square].not_taken?
    end
    false
  end

  def right_border_indices
    results = []
    (x - 1..size - 1).step(x) { |index| results << index }
    results
  end

  def left_border_indices
    results = []
    (0..size - 1).step(x) { |index| results << index }
    results
  end

  def next_square_up(square)
    next_square = square - x
    next_square.negative? ? nil : next_square
  end

  def next_square_right(square)
    return nil if right_border_indices.include?(square)
    square + 1
  end

  def next_square_down(square)
    next_square = square + x
    next_square > size - 1 ? nil : next_square
  end

  def next_square_left(square)
    return nil if left_border_indices.include?(square)
    square - 1
  end

  def reset_normal_squares
    squares.each { |square| square.status = :not_taken }
  end

  # Refactor
  def surrounding_squares(square)
    results = []
    if next_square_up(square)
      results << next_square_up(square)
    end
    if next_square_right(square)
      results << next_square_right(square)
    end
    if next_square_down(square)
      results << next_square_down(square)
    end
    if next_square_left(square)
      results << next_square_left(square)
    end
    results
  end
end

class Square
  attr_reader :type
  attr_accessor :status

  def initialize(type, status)
    @status = status
    @type = type
  end

  def taken?
    return true if status == :taken
    false
  end

  def not_taken?
    !taken?
  end

  def taken!
    self.status = :taken
  end

  def start_square?
    true if type.match(/s/)
  end

  def finish_square?
    true if type.match(/f/)
  end

  def normal_square?
    type == :normal
  end
end

boards = [{ x: 3, y: 2, num_starts: 1, num_barriers: 1, level: 1 }]

# boards = [{ x: 3, y: 2, num_starts: 1, num_barriers: 1, level: 1 },
#           { x: 3, y: 3, num_starts: 1, num_barriers: 1, level: 1 },
#           { x: 3, y: 3, num_starts: 1, num_barriers: 2, level: 1 },
#           { x: 4, y: 3, num_starts: 1, num_barriers: 1, level: 1 },
#           { x: 4, y: 3, num_starts: 1, num_barriers: 2, level: 1 }]

Boards.new(boards)
