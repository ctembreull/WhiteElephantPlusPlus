## Modify String to allow unix color codes for pretty output.
class String
  def colorize(color_code)
    "\e[#{color_code}m#{self}\e[0m"
  end

  def bold_cyan
    colorize("1;96")
  end

  def bold_magenta
    colorize("1;35")
  end

  def bold_red
    colorize("1;31")
  end

  def bold_light_gray
    colorize("1;37")
  end

  def green
    colorize("92")
  end

  def yellow
    colorize("93")
  end
end

# Add some utility methods to Hash
Hash.class_eval {
  def transform_keys
    return enum_for(:transform_keys) unless block_given?
    result = self.class.new
    each_key do |key|
      result[yield(key)] = self[key]
    end
    result
  end

  def deep_transform_keys(&block)
    _deep_transform_keys_in_object(self, &block)
  end

  def _deep_transform_keys_in_object(object, &block)
    case object
    when Hash
      object.each_with_object({}) do |(key, value), result|
        result[yield(key)] = _deep_transform_keys_in_object(value, &block)
      end
    when Array
      object.map {|e| _deep_transform_keys_in_object(e, &block) }
    else
      object
    end
  end
  private :_deep_transform_keys_in_object

  def symbolize_keys
    transform_keys{ |key| key.to_sym rescue key }
  end

  def deep_symbolize_keys
    deep_transform_keys{ |key| key.to_sym rescue key }
  end

  def stringify_keys
    transform_keys{ |key| key.to_s }
  end

  def deep_stringify_keys
    deep_transform_keys{ |key| key.to_s }
  end

  def except(*keys)
    dup.except!(*keys)
  end

  def except!(*keys)
    keys.each { |key| delete(key) }
    self
  end
}
