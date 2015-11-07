class Hero
  attr_reader :name, :email, :key

  def initialize(name, email, key = Time.now.to_i)
    @name = name
    @email = email
    @key = key
  end
end

