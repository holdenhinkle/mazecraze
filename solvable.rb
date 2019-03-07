module Solvable
  def one_solution?
    solutions.size == 1
  end

  def solve(new_attempt)
    new_attempts = new_attempt

    process_attempt = Proc.new do |current_attempt, next_square|
      current_attempt = Marshal.load(Marshal.dump(current_attempt))
      current_grid = current_attempt[:grid]
      current_path = current_attempt[:path].push(next_square)
      current_grid.squares[next_square].taken!
      outcome = check_attempt(current_grid, current_path, next_square)
      solutions << outcome if outcome.is_a? Array
      new_attempts << outcome if outcome.is_a? Hash
    end

    until new_attempts.empty?
      attempt(new_attempts.shift, process_attempt)
    end
  end

  def check_attempt(current_grid, current_path, next_square)
    if current_grid.squares[next_square].finish_square? &&
       current_grid.all_squares_taken?
      current_path
    elsif current_grid.squares[next_square].normal_square?
      { path: current_path, grid: current_grid }
    end
  end

  def attempt(current_attempt, process_attempt)
    current_square = current_attempt[:path].last
    current_grid = current_attempt[:grid]
    process_attempt.call(current_attempt, square_index_above(current_square)) if
      not_taken_square_above?(current_square, current_grid)
    process_attempt.call(current_attempt, square_index_right(current_square)) if
      not_taken_square_right?(current_square, current_grid)
    process_attempt.call(current_attempt, square_index_below(current_square)) if
      not_taken_square_below?(current_square, current_grid)
    process_attempt.call(current_attempt, square_index_left(current_square)) if
      not_taken_square_left?(current_square, current_grid)
  end
end
