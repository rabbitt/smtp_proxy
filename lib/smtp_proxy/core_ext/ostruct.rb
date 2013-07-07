require 'ostruct'
require 'set'

class Hash
  def to_ostruct
    OpenStruct.new(
      self.dup.inject({}) {|h,(k,v)| h[k] = v.respond_to?(:to_ostruct) ? v.to_ostruct : v ; h }
    )
  end
end

class Array
  def to_ostruct
    collect { |v| v.respond_to?(:to_ostruct) ? v.to_ostruct : v }
  end
end

class Set
  def to_ostruct
    collect { |v| v.respond_to?(:to_ostruct) ? v.to_ostruct : v }
  end
end

class OpenStruct
  def _table() @table.dup; end

  def [](key)
    @table[key.to_sym]
  end

  def []=(key, value)
    send("#{key}=".to_sym, value)
  end

  def include?(key)
    @table.keys.include?(key)
  end
end
