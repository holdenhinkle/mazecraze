require 'pry'

# A hash of all boards, with board_type (x/y dimensions) hashes that contain the 
# boards = { board_5x2: [board_object, board_object], board_5x3: [board_object] }
class Boards
  attr_reader :boards

  def initialize(max)
    @boards = {}
    create_boards(3, 2, max)
  end

  private

  def create_boards(x_axis, y_axis, max)
    y_axis.upto(max) do |y_length|
      x_axis.upto(max) do |x_length|
        boards["board_#{x_length}x#{y_length}".to_sym] = Board.new(x_length, y_length)
      end
    end
  end
end

# Each board contains
# size
# x-axis value
# y-axis value
# an array of grids for the board size
class Board
  attr_reader :size, :x_axis_value, :y_axis_value, :grids

  def initialize(x, y)
    @size = x * y
    @x_axis_value = x
    @y_axis_value = y
    @grids = create_grids
  end

  private

  def create_grids
    # How to handle n number of barriers
    grids = []
    0.upto(size - 1) do |start|
      (start + 1).upto(size - 1) do |finish|
        grids << Grid.new(size, start, finish)
      end
    end
    grids << Grid.new(size, 1, 0)
  end

  create seperate method that looks at grid with start and finish, then creates
  new iteration of adding n number of barriers to it

  block 

  def barrier_range
    grid_size = [x_axis_value, y_axis_value].sort
    case grid_size
    when [2, 3] then [1]
    when [3, 3] then [1, 2]
    when [3, 4] then [1, 2]
    when [4, 4] then [2, 3]
    when [4, 5] then [2, 5]
    when [5, 5] then [3, 5]
    end
  end
end
  
# Each grid contains:
# array of sqaures
# grid status
# grid solutions
class Grid
  attr_reader :squares
  attr_accessor :status, :solutions

  def initialize(size, start_index, finish_index)
    @squares = create_grid(size, start_index, finish_index)
    @status = nil
    @solutions = []
    # @number_of_barrier_squares = number_of_barrier_squares
  end

  private

  def create_grid(size, start_index, finish_index)
    grid = []
    size.times do |index|
      grid << if index == start_index
                Square.new(:taken, :start)
              elsif index == finish_index
                Square.new(:not_taken, :finish)
              # elsif barrier.include?(index)
              #   Square.new(:taken, :barrier)
              else
                Square.new(:not_taken, :normal)
              end
    end
    grid
  end
end

# Each square has a status and a type
class Square
  attr_reader :type
  attr_accessor :status

  def initialize(status, type)
    @status = status # can be :taken or :non-taken
    @type = type # can be :start, :end, :normal, :barrier
  end
end

max_board_dimension = 3
boards = Boards.new(max_board_dimension)
binding.pry
puts boards
