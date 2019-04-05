module Navigate
  # OneLine < Maze
  # OneLineBridge < Maze
  def connected_to_start_square?(square)
    surrounding_squares(square).any? { |sq| squares[sq].start_square? }
  end

  # OneLine < Maze
  # MultiLine < Maze
  def surrounding_squares(square)
    results = []
    results << square_index_above(square) if square_above?(square)
    results << square_index_right(square) if square_right?(square)
    results << square_index_below(square) if square_below?(square)
    results << square_index_left(square) if square_left?(square)
    results
  end

  # OneLine < Maze
  # MultiLine < Maze
  def connected_to_more_than_one_normal_square?(square)
    connections = 0
    connections += 1 if normal_not_taken_square_above?(square)
    connections += 1 if normal_not_taken_square_right?(square)
    connections += 1 if normal_not_taken_square_below?(square)
    connections += 1 if normal_not_taken_square_left?(square)
    connections > 1
  end

  # OneLineBridge < Maze
  def connected_to_barrier_square?(square)
    surrounding_squares(square).any? { |sq| squares[sq].barrier_square? }
  end

  # OneLineWarp < Maze, #square_right?(square)
  def right_border_indices
    results = []
    (x - 1..size - 1).step(x) { |index| results << index }
    results
  end

  # OneLineWarp < Maze, #square_left?(square)
  def left_border_indices
    results = []
    (0..size - 1).step(x) { |index| results << index }
    results
  end

  # OneLineWarp < Maze
  # OneLineBridge < Maze
  def border_square?(square)
    return true if top_border_indices.include?(square)
    return true if bottom_border_indices.include?(square)
    return true if right_border_indices.include?(square)
    return true if left_border_indices.include?(square)
    false
  end

  # OneLineWarp < Maze
  # OneLineBridge < Maze
  def top_border_indices
    (0..x - 1).map { |n| n }
  end

  # OneLineWarp < Maze
  # OneLineBridge < Maze
  def bottom_border_indices
    (0..size - 1).map { |n| n }.last(x)
  end

  def square_index_above(square)
    square - x
  end

  def square_index_right(square)
    square + 1
  end

  def square_index_below(square)
    square + x
  end

  def square_index_left(square)
    square - 1
  end

  def square_above?(square)
    square - size >= -(size - x)
  end

  def square_right?(square)
    !right_border_indices.include?(square)
  end

  def square_below?(square)
    square + x < size
  end

  def square_left?(square)
    !left_border_indices.include?(square)
  end

  def start_square_index
    squares.each_with_index do |square, index|
      return index if square.start_square?
    end
  end

  def all_squares_of_type(type)
    squares.each_with_index.with_object([]) do |(square, index), results|
      results << index if
        square.type.match(Regexp.new(Regexp.escape(type)))
    end
  end

  def normal_not_taken_square_above?(square)
    not_taken_square_above?(square) &&
      squares[square_index_above(square)].normal_square?
  end

  def normal_not_taken_square_right?(square)
    not_taken_square_right?(square) &&
      squares[square_index_right(square)].normal_square?
  end

  def normal_not_taken_square_below?(square)
    not_taken_square_below?(square) &&
      squares[square_index_below(square)].normal_square?
  end

  def normal_not_taken_square_left?(square)
    not_taken_square_left?(square) &&
      squares[square_index_left(square)].normal_square?
  end

  def not_taken_square_above?(square, current_maze = self)
    return false unless square_above?(square)
    current_maze.squares[square_index_above(square)].not_taken?
  end

  def not_taken_square_right?(square, current_maze = self)
    return false unless square_right?(square)
    current_maze.squares[square_index_right(square)].not_taken?
  end

  def not_taken_square_below?(square, current_maze = self)
    return false unless square_below?(square)
    current_maze.squares[square_index_below(square)].not_taken?
  end

  def not_taken_square_left?(square, current_maze = self)
    return false unless square_left?(square)
    current_maze.squares[square_index_left(square)].not_taken?
  end
end

module NavigateOneline
end

module NavigateMultiLine
  # MultiLine < Maze
  def connected_to_pair_square?(square)
    surrounding_squares(square).any? do |square_index|
      if squares[square_index].type == :pair
        squares[square_index].group == squares[square].group ? true : false
      else
        false
      end
    end
  end
end

module NavigateBridge
  def valid_not_taken_square_above?(square, current_maze = self)
    return false unless square_above?(square)
    current_square = current_maze.squares[square]
    square_above = current_maze.squares[square_index_above(square)]

    square_above.type == :normal && square_above.not_taken? &&
      current_square.bridge_square? && current_square.vertical_not_taken? ||
      square_above.type == :normal && square_above.not_taken? ||
      square_above.type == :finish && square_above.not_taken? ||
      square_above.type == :bridge && square_above.not_taken? &&
        square_above.vertical_not_taken?
  end

  def valid_not_taken_square_right?(square, current_maze = self)
    return false unless square_right?(square)
    current_square = current_maze.squares[square]
    square_right = current_maze.squares[square_index_right(square)]

    square_right.type == :normal && square_right.not_taken? &&
      current_square.bridge_square? && current_square.horizontal_not_taken? ||
      square_right.type == :normal && square_right.not_taken? ||
      square_right.type == :finish && square_right.not_taken? ||
      square_right.type == :bridge && square_right.not_taken? &&
        square_right.horizontal_not_taken?
  end

  def valid_not_taken_square_below?(square, current_maze = self)
    return false unless square_below?(square)
    current_square = current_maze.squares[square]
    square_below = current_maze.squares[square_index_below(square)]

    square_below.type == :normal && square_below.not_taken? &&
      current_square.bridge_square? && current_square.vertical_not_taken? ||
      square_below.type == :normal && square_below.not_taken? ||
      square_below.type == :finish && square_below.not_taken? ||
      square_below.type == :bridge && square_below.not_taken? &&
        square_below.vertical_not_taken?
  end

  def valid_not_taken_square_left?(square, current_maze = self)
    return false unless square_left?(square)
    current_square = current_maze.squares[square]
    square_left = current_maze.squares[square_index_left(square)]

    square_left.type == :normal && square_left.not_taken? &&
      current_square.bridge_square? && current_square.horizontal_not_taken? ||
      square_left.type == :normal && square_left.not_taken? ||
      square_left.type == :finish && square_left.not_taken? ||
      square_left.type == :bridge && square_left.not_taken? &&
        square_left.horizontal_not_taken?
  end
end

module NavigateTunnel
end

module NavigateWarp
end
