class Rotator
  attr_reader :x, :y

  def initialize(x, y)
    @x = x
    @y = y
  end

  def all_rotations(maze)
    { original: maze, 
      right_90_degree: right_90_degrees(maze),
      right_180_degree: right_180_degrees(maze),
      right_270_degree: right_270_degrees(maze) }
  end

  def right_90_degrees(maze)

  end

  def right_180_degrees(maze)

  end

  def right_270_degrees(maze)

  end
end