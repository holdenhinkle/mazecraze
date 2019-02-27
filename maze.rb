require 'pry'

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
    permutations(layout).each_with_object([]) do |grid_layout, grid_objects|
      grid = Grid.new(board, grid_layout)
      next unless grid.valid?
      grid_objects << grid
    end
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

  def permutations(layout)
    layout.permutation.to_a.uniq
  end

  def count_makers(grid, marker)
    grid.count { |square| square.match(Regexp.new(Regexp.escape(marker))) }
  end

  def format_start_marker(grid)
    s_counter = 0
    grid.each { |marker| s_counter += 1 if marker.match(/s/) }
    "s#{s_counter + 1}"
  end

  def format_finish_marker(grid)
    s_counter = 0
    grid.each { |marker| s_counter += 1 if marker.match(/f/) }
    "f#{s_counter + 1}"
  end
end

class Grid
  attr_reader :squares, :x, :y, :solution, :level

  def initialize(board, grid)
    @squares = create_grid(grid)
    @x = board[:x]
    @y = board[:y]
    @solution = []
    @level = board[:level]
  end

  def valid?
    valid_finish_squares? # && has_one_solution?
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

  # def calculate_solutions
  # end

  def size
    squares.count
  end

  def start_squares
    results = {}
    squares.each_with_index do |square, index| 
      results[square.type] = index if square.type.match(/s/)
    end
    results
  end

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
    connected_to_more_than_one_normal_square?(square)
  end

  def connected_to_start_square?(square)
    if next_square_up(square)
      return true if squares[next_square_up(square)].start_square?
    end
    if next_square_right(square)
      return true if squares[next_square_right(square)].start_square?
    end
    if next_square_down(square)
      return true if squares[next_square_down(square)].start_square?
    end
    if next_square_left(square)
      return true if squares[next_square_left(square)].start_square?
    end
    false
  end

  def connected_to_more_than_one_normal_square?(square)
    connections = 0
    connections += 1 if normal_square_above?(square)
    connections += 1 if normal_square_right?(square)
    connections += 1 if normal_square_below?(square)
    connections += 1 if normal_square_left?(square)
    connections > 1
  end

  def normal_square_above?(square)
    next_square = next_square_up(square)
    if next_square
      return squares[next_square].normal_square? && squares[next_square].not_taken?
    end
    false
  end

  def normal_square_right?(square)
    next_square = next_square_right(square)
    if next_square
      return squares[next_square].normal_square? && squares[next_square].not_taken?
    end
    false
  end

  def normal_square_below?(square)
    next_square = next_square_down(square)
    if next_square
      return squares[next_square].normal_square? && squares[next_square].not_taken?
    end
    false
  end

  def normal_square_left?(square)
    next_square = next_square_left(square)
    if next_square
      return squares[next_square].normal_square? && squares[next_square].not_taken?
    end
    false
  end

  def one_solution?
    solution.size == 1
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
#           { x: 3, y: 2, num_starts: 1, num_barriers: 2, level: 1 }]

all_boards = Boards.new(boards)
binding.pry
p all_boards
