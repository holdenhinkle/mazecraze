require 'singleton'

class Name
  include Singleton

  @names = 0

  attr_reader :a, :b
  attr_accessor :first, :last

  def initialize
    @a = 'apple'
    @b = 'banana'
  end

  def to_s
    first + ' ' + last
  end
end

my_name = Name.instance
