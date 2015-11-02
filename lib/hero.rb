class Hero
  attr_reader :name, :email, :key

  def initialize(name, email)
    @name = name
    @email = email
    @key = Time.now.to_i
  end
end

