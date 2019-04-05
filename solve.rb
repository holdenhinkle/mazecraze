# The solve module solves OneLine mazes and OneLineBridge mazes
module Solve
  def one_solution?
    # solutions.size == 1
    true
  end

  def solve(new_attempt)
    new_attempts = new_attempt
    process_attempt = Proc.new do |current_attempt, next_square|
      current_attempt = Marshal.load(Marshal.dump(current_attempt))
      current_maze = current_attempt[:maze]
      current_path = current_attempt[:path].push(next_square)
      mark_square_taken(current_path, current_maze.squares[next_square])






      # binding.pry
      # travel_through_tunnel if current_maze.type == :one_line_tunnel &&
      #                          current_maze.squares[next_square].type == :tunnel






      outcome = check_attempt(current_maze, current_path, next_square)
      solutions << outcome if outcome.is_a? Array # solved
      new_attempts << outcome if outcome.is_a? Hash # continue
    end
    until new_attempts.empty?
      attempt(new_attempts.shift, process_attempt)
    end
  end

  def attempt(current_attempt, process_attempt)
    current_square = current_attempt[:path].last
    current_maze = current_attempt[:maze]
    process_attempt.call(current_attempt, square_index_above(current_square)) if
      not_taken_square_above?(current_square, current_maze)
    process_attempt.call(current_attempt, square_index_right(current_square)) if
      not_taken_square_right?(current_square, current_maze)
    process_attempt.call(current_attempt, square_index_below(current_square)) if
      not_taken_square_below?(current_square, current_maze)
    process_attempt.call(current_attempt, square_index_left(current_square)) if
      not_taken_square_left?(current_square, current_maze)
  end

  def mark_square_taken(_, square)
    square.taken!
  end
end

module SolveOneLine
  # def attempt(current_attempt, process_attempt)
  #   current_square = current_attempt[:path].last
  #   current_maze = current_attempt[:maze]
  #   process_attempt.call(current_attempt, square_index_above(current_square)) if
  #     not_taken_square_above?(current_square, current_maze)
  #   process_attempt.call(current_attempt, square_index_right(current_square)) if
  #     not_taken_square_right?(current_square, current_maze)
  #   process_attempt.call(current_attempt, square_index_below(current_square)) if
  #     not_taken_square_below?(current_square, current_maze)
  #   process_attempt.call(current_attempt, square_index_left(current_square)) if
  #     not_taken_square_left?(current_square, current_maze)
  # end

  def check_attempt(current_maze, current_path, next_square)
    if current_maze.squares[next_square].finish_square? &&
       current_maze.all_squares_taken?
      current_path
    elsif current_maze.squares[next_square].normal_square?
      { path: current_path, maze: current_maze }
    end
  end
end

module SolveBridge
  def attempt(current_attempt, process_attempt)
    current_square = current_attempt[:path].last
    current_maze = current_attempt[:maze]
    process_attempt.call(current_attempt, square_index_above(current_square)) if
      valid_not_taken_square_above?(current_square, current_maze)
    process_attempt.call(current_attempt, square_index_right(current_square)) if
      valid_not_taken_square_right?(current_square, current_maze)
    process_attempt.call(current_attempt, square_index_below(current_square)) if
      valid_not_taken_square_below?(current_square, current_maze)
    process_attempt.call(current_attempt, square_index_left(current_square)) if
      valid_not_taken_square_left?(current_square, current_maze)
  end

  def check_attempt(current_maze, current_path, next_square)
    if current_maze.squares[next_square].finish_square? &&
       current_maze.all_squares_taken?
      current_path
    elsif current_maze.squares[next_square].normal_square? ||
          current_maze.squares[next_square].bridge_square?
      { path: current_path, maze: current_maze }
    end
  end

  def mark_square_taken(current_path, square)
    square.type != :bridge ? square.taken! : update_bridge_square(current_path, square)
  end

  def update_bridge_square(current_path, square)
    current_square_index = current_path.last
    previous_square_index = current_path[current_path.size - 2]
    if square_index_above(current_square_index) == previous_square_index ||
       square_index_below(current_square_index) == previous_square_index
      square.vertical_taken!
    else
      square.horizontal_taken!
    end
    square.taken! if square.horizontal_taken? && square.vertical_taken?
  end
end

module SolveTunnel
  def check_attempt(current_maze, current_path, next_square)
    if current_maze.squares[next_square].finish_square? && # if soloved
       current_maze.all_squares_taken?
      current_path
    elsif current_maze.squares[next_square].normal_square? || # continue
          current_maze.squares[next_square].bridge_square?
      { path: current_path, maze: current_maze }
    end
  end

  def mark_square_taken(_, square)
    square.taken!
  end
end

module SolvePortal
end
