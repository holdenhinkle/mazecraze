module Navigable
  def connected_to_start_square?(square)
    surrounding_squares(square).any? { |sq| squares[sq].start_square? }
  end

  def connected_to_pair_square?(square)
    surrounding_squares(square).any? do |square_index|
      if squares[square_index].type == :pair
        squares[square_index].group == squares[square].group ? true : false
      else
        false
      end
    end
  end

  def connected_to_more_than_one_normal_square?(square)
    connections = 0
    connections += 1 if normal_not_taken_square_above?(square)
    connections += 1 if normal_not_taken_square_right?(square)
    connections += 1 if normal_not_taken_square_below?(square)
    connections += 1 if normal_not_taken_square_left?(square)
    connections > 1
  end

  def surrounding_squares(square)
    results = []
    results << square_index_above(square) if square_above?(square)
    results << square_index_right(square) if square_right?(square)
    results << square_index_below(square) if square_below?(square)
    results << square_index_left(square) if square_left?(square)
    results
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

  def not_taken_square_above?(square, current_grid = self)
    return false unless square_above?(square)
    current_grid.squares[square_index_above(square)].not_taken?
  end

  def not_taken_square_right?(square, current_grid = self)
    return false unless square_right?(square)
    current_grid.squares[square_index_right(square)].not_taken?
  end

  def not_taken_square_below?(square, current_grid = self)
    return false unless square_below?(square)
    current_grid.squares[square_index_below(square)].not_taken?
  end

  def not_taken_square_left?(square, current_grid = self)
    return false unless square_left?(square)
    current_grid.squares[square_index_left(square)].not_taken?
  end
end
