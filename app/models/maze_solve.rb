module MazeCraze
  module MazeSolve
    def solve(attempts)
      until attempts.empty?
        attempt(attempts.shift) do |current_attempt, next_square|
          current_attempt = Marshal.load(Marshal.dump(current_attempt))
          current_maze = current_attempt[:maze]
          current_path = current_attempt[:path].push(next_square)
          mark_square_taken!(current_maze, current_path, current_maze.squares[next_square])
          outcome = check_attempt(current_maze, current_path, next_square)
          next if outcome.nil?
          solutions << outcome[:solution] && next if outcome[:solution]
          attempts << outcome
        end
      end
    end

    def attempt(current_attempt)
      current_square = current_attempt[:path].last
      current_maze = current_attempt[:maze]
      yield(current_attempt, square_index_above(current_square)) if
        valid_move?('above', current_square, current_maze)
      yield(current_attempt, square_index_right(current_square)) if
        valid_move?('right', current_square, current_maze)
      yield(current_attempt, square_index_below(current_square)) if
        valid_move?('below', current_square, current_maze)
      yield(current_attempt, square_index_left(current_square)) if
        valid_move?('left', current_square, current_maze)
    end

    def mark_square_taken!(_, _, square)
      square.taken!
    end

    def check_attempt(current_maze, current_path, next_square)
      if current_maze.squares[next_square].finish_square? &&
         current_maze.all_squares_taken?
        { solution: current_path }
      elsif current_maze.squares[next_square].normal_square?
        { path: current_path, maze: current_maze }
      end
    end
  end

  module SolveBridgeMaze
    def check_attempt(current_maze, current_path, next_square)
      if current_maze.squares[next_square].finish_square? &&
         current_maze.all_squares_taken?
        { solution: current_path }
      elsif current_maze.squares[next_square].normal_square? ||
            current_maze.squares[next_square].bridge_square?
        { path: current_path, maze: current_maze }
      end
    end

    def mark_square_taken!(_, current_path, square)
      if square.type == :bridge
        update_bridge_square!(current_path, square)
      else
        square.taken!
      end
    end

    def update_bridge_square!(current_path, square)
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

  module SolveTunnelMaze
    def mark_square_taken!(current_maze, current_path, square)
      square.taken!
      return unless square.tunnel_square?
      other_end_of_tunnel_square =
        current_maze.squares[other_end_of_tunnel_index(current_maze, square)]
      current_path.push(other_end_of_tunnel_square.index)
      other_end_of_tunnel_square.taken!
    end

    def check_attempt(current_maze, current_path, next_square)
      if current_maze.squares[next_square].finish_square? &&
         current_maze.all_squares_taken?
        { solution: current_path }
      elsif current_maze.squares[next_square].normal_square? ||
            current_maze.squares[next_square].tunnel_square?
        { path: current_path, maze: current_maze }
      end
    end
  end

  module SolvePortalMaze
    def mark_square_taken!(current_maze, current_path, square)
      square.taken!
      return unless square.portal_square?
      other_end_of_portal_square = if top_border_indices.include?(square.index) ||
                                      bottom_border_indices.include?(square.index)
                                     current_maze.squares[size - square.index - 2]
                                   elsif left_border_indices.include?(square.index)
                                     current_maze.squares[square.index + x - 1]
                                   else
                                     current_maze.squares[x - square.index - 1]
                                   end
      current_path.push(other_end_of_portal_square.index)
      other_end_of_portal_square.taken!
    end

    def check_attempt(current_maze, current_path, next_square)
      if current_maze.squares[next_square].finish_square? &&
         current_maze.all_squares_taken?
        { solution: current_path }
      elsif current_maze.squares[next_square].normal_square? ||
            current_maze.squares[next_square].portal_square?
        { path: current_path, maze: current_maze }
      end
    end
  end
end
