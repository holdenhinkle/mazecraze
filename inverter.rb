class Inverter
  attr_reader :x, :y

  def initialize(x, y)
    @x = x
    @y = y
  end

  def all_inversions(maze)
    { original: maze, 
      horizontal: horizontal(maze.clone),
      vertical: vertical(maze.clone) }
  end

  private

  # if any of the following methods are made public, the maze local
  # variable must be cloned.

  def horizontal(maze)
    process_inversion(maze) { |maze| maze.shift(x).reverse! }
  end

  def vertical(maze)
    process_inversion(maze) { |maze| maze.pop(x) }
  end

  def process_inversion(maze)
    flipped_maze = []
    y.times do
      flipped_maze << yield(maze)
    end
    flipped_maze.flatten!
    flipped_maze
  end
end