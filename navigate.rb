module Navigate
  def number_of_squares_by_type(type)
    squares.count { |square| square.type == type }
  end

  def connected_to_start_square?(square)
    surrounding_squares(square).any? { |sq| squares[sq].start_square? }
  end

  def surrounding_squares(square_index)
    results = []
    results << square_index_above(square_index) if square_above_exists?(square_index)
    results << square_index_right(square_index) if square_right_exists?(square_index)
    results << square_index_below(square_index) if square_below_exists?(square_index)
    results << square_index_left(square_index) if square_left_exists?(square_index)
    results
  end

  def connected_to_more_than_one_normal_square?(square_index)
    connections = 0
    connections += 1 if square_above_exists?(square_index) &&
                        square_not_taken_and_is_of_type('above', square_index, :normal)
    connections += 1 if square_right_exists?(square_index) &&
                        square_not_taken_and_is_of_type('right', square_index, :normal)
    connections += 1 if square_below_exists?(square_index) &&
                        square_not_taken_and_is_of_type('below', square_index, :normal)
    connections += 1 if square_left_exists?(square_index) &&
                        square_not_taken_and_is_of_type('left', square_index, :normal)
    connections > 1
  end

  # OneLineBridge < Maze
  def connected_to_barrier_square?(square_index)
    surrounding_squares(square_index).any? { |square| squares[square].barrier_square? }
  end

  # OneLinePortal < Maze, #square_right_exists?(square)
  def right_border_indices
    results = []
    (x - 1..size - 1).step(x) { |index| results << index }
    results
  end

  # OneLinePortal < Maze, #square_left_exists?(square)
  def left_border_indices
    results = []
    (0..size - 1).step(x) { |index| results << index }
    results
  end

  # OneLinePortal < Maze
  # OneLineBridge < Maze
  def border_square?(square_index)
    return true if top_border_indices.include?(square_index)
    return true if bottom_border_indices.include?(square_index)
    return true if right_border_indices.include?(square_index)
    return true if left_border_indices.include?(square_index)
    false
  end

  # OneLinePortal < Maze
  # OneLineBridge < Maze
  def top_border_indices
    (0..x - 1).map { |n| n }
  end

  # OneLinePortal < Maze
  # OneLineBridge < Maze
  def bottom_border_indices
    (0..size - 1).map { |n| n }.last(x)
  end

  def start_square_index
    squares.each do |square|
      return square.index if square.start_square?
    end
  end

  def all_squares_of_type(type)
    squares.each_with_object([]) do |square, results|
      results << square.index if
        square.type.match(Regexp.new(Regexp.escape(type)))
    end
  end

  def square_index_above(square_index)
    square_index - x
  end

  def square_index_right(square_index)
    square_index + 1
  end

  def square_index_below(square_index)
    square_index + x
  end

  def square_index_left(square_index)
    square_index - 1
  end

  def square_above_exists?(square_index)
    square_index - size >= -(size - x)
  end

  def square_right_exists?(square_index)
    !right_border_indices.include?(square_index)
  end

  def square_below_exists?(square_index)
    square_index + x < size
  end

  def square_left_exists?(square_index)
    !left_border_indices.include?(square_index)
  end

  def square_not_taken?(direction, square_index, current_maze = self)
    current_maze.squares[send("square_index_#{direction}", square_index)].not_taken?
  end

  def square_not_taken_and_is_of_type(direction, square_index, type, current_maze = self)
    square_not_taken?(direction, square_index, current_maze) &&
      current_maze.squares[send("square_index_#{direction}", square_index)].type == type
  end

  def valid_move?(direction, square_index, current_maze = self)
    send("square_#{direction}_exists?", square_index) &&
      square_not_taken?(direction, square_index, current_maze)
  end

  # MultiLine
  def connected_to_endpoint_square?(square)
    binding.pry
    surrounding_squares(square).any? do |square_index|
      if squares[square_index].type == :endpoint
        squares[square_index].group == squares[square].group ? true : false
      else
        false
      end
    end
  end
end

module NavigateBridge
  def valid_move?(direction, square_index, current_maze = self)
    return false unless send("square_#{direction}_exists?", square_index)
    bridge_direction = determine_bridge_direction(direction)
    current_square = current_maze.squares[square_index]
    other_square = current_maze.squares[send("square_index_#{direction}", square_index)]

    square_not_taken_and_is_of_type(direction, square_index, :normal, current_maze) &&
      square_is_type_bridge_and_bridge_direction_not_taken?(current_square, bridge_direction) ||
      square_not_taken_and_is_of_type(direction, square_index, :normal, current_maze) ||
      square_not_taken_and_is_of_type(direction, square_index, :endpoint, current_maze) ||
      square_not_taken_and_is_of_type(direction, square_index, :bridge, current_maze) &&
        bridge_direction_not_taken?(other_square, bridge_direction)
  end

  def determine_bridge_direction(direction)
    if %w(above below).include?(direction)
      'vertical'
    else
      'horizontal'
    end
  end

  def square_is_type_bridge_and_bridge_direction_not_taken?(square, direction)
    return false unless square.bridge_square?
    bridge_direction_not_taken?(square, direction)
  end

  def bridge_direction_not_taken?(square, direction)
    method_name = "#{direction}_not_taken?"
    square.send(method_name)
  end
end

module NavigateTunnel
  def valid_move?(direction, square_index, current_maze = self)
    return false unless send("square_#{direction}_exists?", square_index)
  end
end

module NavigatePortal
  def valid_move?(direction, square_index, current_maze = self)
    return false unless send("square_#{direction}_exists?", square_index)
  end
end
