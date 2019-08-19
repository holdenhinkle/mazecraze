module ApplicationHelper
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

  def format_timestamp(timestamp)
    time = convert_timestamp_to_time(timestamp)
    "#{date(time)}, #{time(time)}"
  end

  def elapsed_time(start_timestamp)
    start = convert_timestamp_to_time(start_timestamp)
    now = Time.now
    time_difference_to_s(now, start)
  end

  def total_time(start_timestamp, finish_timestamp)
    start = convert_timestamp_to_time(start_timestamp)
    finish = convert_timestamp_to_time(finish_timestamp)
    time_difference_to_s(finish, start)
  end

  def convert_timestamp_to_time(timestamp)
    date, time = timestamp.split(' ')
    year, month, day = parse_date(date)
    hours, minutes, seconds = parse_time(time)
    Time.new(year, month, day, hours, minutes, seconds)
  end

  def time_difference_to_s(new_time, old_time)
    "#{format('%.4f', (new_time - old_time))} seconds"
  end

  def parse_date(date)
    date.split('-').each(&:to_i)
  end

  def parse_time(time)
    hours, minutes, seconds = time.split(':')
    hours = hours.to_i
    minutes = minutes.to_i
    seconds = seconds.to_f
    return hours, minutes, seconds
  end

  def date(date)
    date.strftime("%m/%d/%Y")
  end

  def time(time)
    time.strftime("%I:%M %p")
  end

  def add_hash_to_session_hash(hash)
    hash.each { |key, value| session[key] = value }
  end
end
