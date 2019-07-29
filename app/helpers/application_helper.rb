module ApplicationHelper
  # REDO THIS
  def title(value = nil)
    @title = value if value
    @title ? "#{@title} :: Maze Craze" : 'Maze Craze'
  end

  def underscores_to_spaces(string)
    return string unless string.include?('_')
    string.tr!('_', ' ')
  end

  def capitalize_words(string)
    string.split(' ').map(&:capitalize).join(' ')
  end

  def format_background_job_params(params)
    JSON.parse(params).each_with_object([]) do |(key, value), array|
      string = ''
      string << capitalize_words(underscores_to_spaces(+key)) + ': '
      string << value.capitalize
      array << string
    end.join(', ')
  end

  # def replace_underscores_with_space(str)
  #   return str unless str.include?('_')
  #   str.gsub!('_', ' ')
  # end

  # REDO THIS
  # def array_to_string(array)
  #   result = ""
  #   array.each_with_index do |element, index|
  #     return element if array.size == 1
  #     return "#{element} and #{array[index + 1]}" if array.size == 2
  #     result << element
  #     if index == array.size - 2
  #       return result << ", and #{array[index + 1]}"
  #     else 
  #       result << ', '
  #     end
  #   end
  # end

  def add_hash_to_session_hash(hash)
    hash.each { |key, value| session[key] = value }
  end
end
