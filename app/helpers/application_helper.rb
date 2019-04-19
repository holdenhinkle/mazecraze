module ApplicationHelper
  def title(value = nil)
    @title = value if value
    @title ? "#{@title} :: Maze Craze" : 'Maze Craze'
  end
end
