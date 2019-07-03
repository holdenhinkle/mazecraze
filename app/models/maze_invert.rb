module MazeCraze
  class MazeInvert
    attr_reader :x, :y

    def initialize(x, y)
      @x = x
      @y = y
    end

    def all_inversions(maze)
      { horizontal: horizontal(maze.clone),
        vertical: vertical(maze.clone) }
    end

    private

    # if any of the following methods are made public, the maze local
    # variable in the methods must be cloned.

    def horizontal(maze)
      process_inversion(maze) { |mz| mz.shift(x).reverse! }
    end

    def vertical(maze)
      process_inversion(maze) { |mz| mz.pop(x) }
    end

    def process_inversion(maze)
      inverted_maze = []
      y.times do
        inverted_maze << yield(maze)
      end
      inverted_maze.flatten!
      inverted_maze
    end
  end
end
