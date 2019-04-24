class FlipMaze
  attr_reader :x, :y

  def initialize(x, y)
    @x = x
    @y = y
  end

  def all_flips(maze)
    { horizontal: horizontal(maze.clone),
      vertical: vertical(maze.clone) }
  end

  private

  # if any of the following methods are made public, the maze local
  # variable in the methods must be cloned.

  def horizontal(maze)
    process_flip(maze) { |mz| mz.shift(x).reverse! }
  end

  def vertical(maze)
    process_flip(maze) { |mz| mz.pop(x) }
  end

  def process_flip(maze)
    flipped_maze = []
    y.times do
      flipped_maze << yield(maze)
    end
    flipped_maze.flatten!
    flipped_maze
  end
end