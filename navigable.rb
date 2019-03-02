module Navigable
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
    (square - x).positive?
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
    results = {}
    squares.each_with_index do |square, index|
      results[square.type] = index if 
        square.type.match(Regexp.new(Regexp.escape(type)))
    end
    results
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

  def connected_to_start_square?(square)
    surrounding_squares(square).any? { |sq| squares[sq].start_square? }
  end
end
