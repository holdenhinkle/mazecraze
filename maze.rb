# A hash of all boards, with board_type (x/y dimensions) hashes that contain the 
# boards = { board_5x2: [board_object, board_object], board_5x3: [board_object] }
class AllBoards
  attr_accessor :boards

  def initialize(max)
    @boards = create_boards(3, 2, max)
  end

  private

  def create_boards(x_axis, y_axis, max)
    y_axis.upto(max) do |y_length|
      x_axis.upto(max) do |x_length|
        boards["board#{x_length}x#{y_length}".to_sym] = Board.new(x_length, y_length)
      end
    end
  end
end

# Each board is comprised of a grid that has a status (valid/invalid) and one or more solutions (if valid)
# This is a board, which contains the grid, number of barrier squares, board_status 
# (valid, invalid), solutions
# board = { grid: [square_object, square_object..n], status: :valid, solutions: [] }
class Board
  attr_reader :grid
  attr_accessor :status, :solutions

  def initialize(x, y)
    @grid = create_grid(x, y)
    @status = nil
    @solutions = []
  end

  private

  def create_grid(x, y)
    #  (barrier_range(x, y).min).upto(barrier_range(x, y).max) do |num_barriers|
      
    # given grid layout, like 5 x 3
    # we need to do three iterations:
    # where start is
    # where finish is
    # number of barriers
    # where barrier(s) are

    return is a square

  end

  def barrier_range(x, y)
    grid_size = [x, y].sort
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
  
# Each grid contains and array of sqaures, x and y values, and number of barriers in the grid
# grid = [ [square_object, square_object, square_object],
#          [square_object, square_object, square_object] ]
class Grid
  attr_reader :x_cord, :y_cord

  def initialize(x, y)
    @x_axis_value = x
    @y_axis_value = y
    @number_of_barrier_squares = number_of_barrier_squares
    @squares = draw_grid(x, y, number_of_barrier_squares)
  end

  private

  def draw_grid(x, y, number_of_barrier_squares)
  end
end

# Each square has a status and a type
class Square
  attr_accessor :status

  def initialize(status, type)
    @status = status # can be :taken or :non-taken
    @type = type # can be :start, :end, :normal, :barrier
  end
end

boards = AllBoards.new(5) # 5 is the max x/y grid coordinate value, which will create all grids
                          # up to that size.


