require 'pry'

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

class Board
  attr_reader :size, :x_axis_length, :y_axis_length, :grids

  def initialize(x, y)
    @size = x * y
    @x_axis_length = x
    @y_axis_length = y
    @grids = create_grids
  end

  private

  def create_grids
    grid_permutations.each_with_object([]) do |grid_layouts, grid_objects|
      grid_layouts.each do |grid_layout|
        grid = Grid.new(grid_layout)
        next unless grid.valid?
        grid_objects << grid
      end
    end
  end

  def grid_permutations
    # redo this with each with object to shorted method length?
    grids = []
    barrier_range.min.upto(barrier_range.max) do |number_of_barriers|
      grid = []
      size.times do
        grid << if grid.none?('s')
                  's'
                elsif grid.none?('f')
                  'f'
                elsif grid.count('b') != number_of_barriers
                  'b'
                else
                  'n'
                end
      end
      grids << grid
    end
    grids.map { |g| g.permutation.to_a.uniq }
  end

  def barrier_range
    grid_size = [x_axis_length, y_axis_length].sort
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

class Grid
  attr_reader :squares
  attr_accessor :status, :solutions

  def initialize(grid)
    @squares = create_grid(grid)
    @status = nil
    @solutions = []
  end

  private

  def create_grid(grid)
    grid.each.map do |square|
      case square
      when 's' then Square.new(:start, :taken)
      when 'f' then Square.new(:finish, :not_taken)
      when 'b' then Square.new(:barrier, :taken)
      when 'n' then Square.new(:normal, :not_taken)
      end
    end
  end

  def valid?
    valid_finish_square? && has_one_solution?
  end

  def valid_finish_square?
  end

  def has_one_solution?
    calculate_solutions
    solutions.size == 1
  end

  def calculate_solutions
  end
end

class Square
  attr_reader :type
  attr_accessor :status

  def initialize(type, status)
    @status = status
    @type = type
  end
end

max_board_dimension = 3
boards = Boards.new(max_board_dimension)
