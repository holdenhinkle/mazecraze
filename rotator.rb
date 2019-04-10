class Rotator
  attr_reader :x, :y

  def initialize(x, y)
    @x = x
    @y = y
  end

  def all_rotations(maze)
    return { right_180_degrees: right_180_degrees(maze.clone) } if x != y
    { right_90_degrees: right_90_degrees(maze.clone),
      right_180_degrees: right_180_degrees(maze.clone),
      right_270_degrees: right_270_degrees(maze.clone) }
  end

  private

  # if any of the following methods are made public, the maze local
  # variable in the methods must be cloned.

  def right_90_degrees(maze, shifted_maze = [])
    shifted_maze.unshift(maze.shift(x))
    right_90_degrees(maze, shifted_maze) unless maze.empty?
    shifted_maze.flatten!
    rotated_maze = []
    x.times do |starting_index|
      (starting_index...shifted_maze.length).step(x).each do |index|
        rotated_maze << shifted_maze[index]
      end
    end
    rotated_maze
  end

  def right_180_degrees(maze)
    maze.reverse!
  end

  def right_270_degrees(maze)
    right_90_degrees(maze).reverse!
  end
end
