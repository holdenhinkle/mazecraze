class Inverter
  attr_reader :x, :y

  def initialize(x, y)
    @x = x
    @y = y
  end

  def all_inversions(maze)
    { original: maze, 
      horizontal: horizontal(maze),
      vertical: vertical(maze) }
  end

  def horizontal(maze)

  end

  def vertical(maze)

  end
end