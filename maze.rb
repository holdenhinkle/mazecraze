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
    @grids = create_grids(x, y)
  end

  private

  def create_grids(x, y)
    grid_permutations.each_with_object([]) do |grid_layouts, grid_objects|
      grid_layouts.each do |grid_layout|
        grid = Grid.new(grid_layout, x, y)
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
    when [2, 4] then [1, 2] # DELETE - FOR TESTING PURPOSES
    when [3, 4] then [1, 2]
    when [4, 4] then [2, 3]
    when [4, 5] then [2, 5]
    when [5, 5] then [3, 5]
    end
  end
end

class Grid
  attr_reader :squares, :x, :y, :start, :finish, :size
  attr_accessor :status, :solution

  def initialize(grid, x, y)
    @size = x * y
    @start = nil
    @finish = nil
    @squares = create_grid(grid)
    @x = x
    @y = y
    # @solution = calculate_solutions
    # @level = game_level
  end

  def valid?
    valid_finish_square? # && has_one_solution?
  end

  private

  def create_grid(grid)
    grid.each.map.with_index do |square, index|
      case square
      when 's'
        @start = index
        Square.new(:start, :taken)
      when 'f'
        @finish = index
        Square.new(:finish, :not_taken)
      when 'b' then Square.new(:barrier, :taken)
      when 'n' then Square.new(:normal, :not_taken)
      end
    end
  end

  # def game_level
  # end

  # def calculate_solutions
  # end

  def valid_finish_square?
    connections = 0
    if normal_square_above?
      connections += 1
    elsif normal_square_right?
      connections += 1
      return false if connections > 1
    elsif normal_square_below?
      connections += 1
      return false if connections > 1
    elsif normal_square_left?
      connections += 1
      return false if connections > 1
    end
    true
  end


  # PASS IN SQUARE TO THE FOLLOWING METHODS SO THEY CAN BE REUSED
  # RIGHT NOW THEY ONLY HAVE TO DO WITH 'FINISH' SQUARE
  # RENAME FINISH SQUARE SO I CAN CALL THE 'FINISH' SQUARE IN IRB

  # AND MAKE THE 'FINISH' SQUARE NOT NEXT TO 'START' SQUARE - THIS WON'T WORK FOR VALIDATION
  # OF NON-FINISH SQUARES
  def normal_square_above?
    square = finish - x
    return false if square.negative? || squares[square].taken?
    true
  end

  def normal_square_right?
    return false if right_border_indices.include?(finish) ||
                    squares[finish + 1].taken?
    true
  end

  def normal_square_below?
    square = finish + x
    return false if square > size - 1 || squares[square].taken?
    true
  end

  def normal_square_left?
    return false if left_border_indices.include?(finish) ||
                    squares[finish - 1].taken?
    true
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
end

max_board_dimension = 4
boards = Boards.new(max_board_dimension)

p boards