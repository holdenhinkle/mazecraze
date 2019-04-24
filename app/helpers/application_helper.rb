module ApplicationHelper
  # REDO THIS
  def title(value = nil)
    @title = value if value
    @title ? "#{@title} :: Maze Craze" : 'Maze Craze'
  end

  def replace_underscores_with_space(str)
    return str unless str.include?('_')
    str.gsub!('_', ' ')
  end

  # REDO THIS
  def array_to_string(array)
    result = ""
    array.each_with_index do |element, index|
      return element if array.size == 1
      return "#{element} and #{array[index + 1]}" if array.size == 2
      result << element
      if index == array.size - 2
        return result << ", and #{array[index + 1]}"
      else 
        result << ', '
      end
    end
  end

  def convert_empty_quotes_to_zero(params)
    params.each do |key, value| 
      value == '' ? params[key] = '0' : params[key] = value
    end
  end
end
